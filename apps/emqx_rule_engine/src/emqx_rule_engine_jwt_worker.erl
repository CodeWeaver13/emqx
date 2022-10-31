%%--------------------------------------------------------------------
%% Copyright (c) 2022 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_rule_engine_jwt_worker).

-behaviour(gen_server).

%% API
-export([ start_link/2
        ]).

%% gen_server API
-export([ init/1
        , handle_continue/2
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , format_status/1
        , format_status/2
        ]).

-include_lib("jose/include/jose_jwk.hrl").
-include_lib("emqx_rule_engine/include/rule_engine.hrl").
-include_lib("emqx_rule_engine/include/rule_actions.hrl").
-include_lib("snabbkaffe/include/snabbkaffe.hrl").

-type config() :: #{ private_key := binary()
                   , resource_id := resource_id()
                   , expiration := timer:time()
                   , table := ets:table()
                   , iss := binary()
                   , sub := binary()
                   , aud := binary()
                   , kid := binary()
                   , alg := binary()
                   }.
-type jwt() :: binary().
-type state() :: #{ refresh_timer := undefined | timer:tref()
                  , resource_id := resource_id()
                  , expiration := timer:time()
                  , table := ets:table()
                  , jwt := undefined | jwt()
                    %% only undefined during startup
                  , jwk := undefined | jose_jwk:key()
                  , iss := binary()
                  , sub := binary()
                  , aud := binary()
                  , kid := binary()
                  , alg := binary()
                  }.

-define(refresh_jwt, refresh_jwt).

%%-----------------------------------------------------------------------------------------
%% API
%%-----------------------------------------------------------------------------------------

-spec start_link(config(), reference()) -> gen_server:start_ret().
start_link(#{ private_key := _
            , expiration := _
            , resource_id := _
            , table := _
            , iss := _
            , sub := _
            , aud := _
            , kid := _
            , alg := _
            } = Config,
           Ref) ->
    gen_server:start_link(?MODULE, {Config, Ref}, []).

%%-----------------------------------------------------------------------------------------
%% gen_server API
%%-----------------------------------------------------------------------------------------

-spec init({config(), Ref}) -> {ok, state(), {continue, {make_key, binary(), Ref}}}
                               | {stop, {error, term()}}
              when Ref :: reference().
init({#{private_key := PrivateKeyPEM} = Config, Ref}) ->
    State0 = maps:without([private_key], Config),
    State = State0#{ jwk => undefined
                   , jwt => undefined
                   , refresh_timer => undefined
                   },
    {ok, State, {continue, {make_key, PrivateKeyPEM, Ref}}}.

handle_continue({make_key, PrivateKeyPEM, Ref}, State0) ->
    case jose_jwk:from_pem(PrivateKeyPEM) of
        JWK = #jose_jwk{} ->
            State = State0#{jwk := JWK},
            {noreply, State, {continue, {create_token, Ref}}};
        [] ->
            Ref ! {Ref, {error, {invalid_private_key, empty_key}}},
            {stop, {error, empty_key}, State0};
        {error, Reason} ->
            Ref ! {Ref, {error, {invalid_private_key, Reason}}},
            {stop, {error, Reason}, State0};
        Error ->
            Ref ! {Ref, {error, {invalid_private_key, Error}}},
            {stop, {error, Error}, State0}
    end;
handle_continue({create_token, Ref}, State0) ->
    JWT = do_generate_jwt(State0),
    store_jwt(State0, JWT),
    State1 = State0#{jwt := JWT},
    State = ensure_timer(State1),
    Ref ! {Ref, token_created},
    {noreply, State}.

handle_call(_Req, _From, State) ->
    {reply, {error, bad_call}, State}.

handle_cast(_Req, State) ->
    {noreply, State}.

handle_info({timeout, TRef, ?refresh_jwt}, State0 = #{refresh_timer := TRef}) ->
    JWT = do_generate_jwt(State0),
    store_jwt(State0, JWT),
    ?tp(rule_engine_jwt_worker_refresh, #{}),
    State1 = State0#{jwt := JWT},
    State = ensure_timer(State1#{refresh_timer := undefined}),
    {noreply, State};
handle_info(_Msg, State) ->
    {noreply, State}.

format_status(State) ->
    censor_secrets(State).

format_status(_Opt, [_PDict, State0]) ->
    State = censor_secrets(State0),
    [{data, [{"State", State}]}].

%%-----------------------------------------------------------------------------------------
%% Helper fns
%%-----------------------------------------------------------------------------------------

-spec do_generate_jwt(state()) -> jwt().
do_generate_jwt(#{ expiration := ExpirationMS
                 , iss := Iss
                 , sub := Sub
                 , aud := Aud
                 , kid := KId
                 , alg := Alg
                 , jwk := JWK
                 } = _State) ->
    Headers = #{ <<"alg">> => Alg
               , <<"kid">> => KId
               },
    Now = erlang:system_time(seconds),
    ExpirationS = erlang:convert_time_unit(ExpirationMS, millisecond, second),
    Claims = #{ <<"iss">> => Iss
              , <<"sub">> => Sub
              , <<"aud">> => Aud
              , <<"iat">> => Now
              , <<"exp">> => Now + ExpirationS
              },
    JWT0 = jose_jwt:sign(JWK, Headers, Claims),
    {_, JWT} = jose_jws:compact(JWT0),
    JWT.

-spec store_jwt(state(), jwt()) -> ok.
store_jwt(#{resource_id := ResourceId, table := TId}, JWT) ->
    true = ets:insert(TId, {{ResourceId, jwt}, JWT}),
    ?tp(jwt_worker_token_stored, #{resource_id => ResourceId}),
    ok.

-spec ensure_timer(state()) -> state().
ensure_timer(State = #{ refresh_timer := undefined
                      , expiration := ExpirationMS0
                      }) ->
    ExpirationMS = max(5_000, ExpirationMS0 - 5_000),
    TRef = erlang:start_timer(ExpirationMS, self(), ?refresh_jwt),
    State#{refresh_timer => TRef};
ensure_timer(State) ->
    State.

-spec censor_secrets(state()) -> map().
censor_secrets(State) ->
    maps:map(
     fun(Key, _Value) when Key =:= jwt;
                           Key =:= jwk ->
             "******";
        (_Key, Value) ->
             Value
     end,
     State).
