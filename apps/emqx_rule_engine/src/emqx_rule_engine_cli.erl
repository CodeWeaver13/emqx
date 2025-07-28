%%--------------------------------------------------------------------
%% Copyright (c) 2022-2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------
-module(emqx_rule_engine_cli).

%% API:
-export([load/0, unload/0]).

-export([cmd/1]).

-include_lib("emqx/include/emqx_config.hrl").

%%================================================================================
%% API functions
%%================================================================================

load() ->
    ok = emqx_ctl:register_command(rules, {?MODULE, cmd}, []).

unload() ->
    ok = emqx_ctl:unregister_command(rules).

%%================================================================================
%% Internal exports
%%================================================================================

cmd(["list"]) ->
    lists:foreach(
        fun pretty_print_rule_summary/1,
        %% TODO: namespace
        emqx_rule_engine:get_rules_ordered_by_ts(?global_ns)
    );
cmd(["show", Id]) ->
    pretty_print_rule(Id);
cmd(_) ->
    emqx_ctl:usage(
        [
            {"rules list", "List rules"},
            {"rules show <RuleId>", "Show a rule"}
        ]
    ).

%%================================================================================
%% Internal functions
%%================================================================================

pretty_print_rule_summary(#{id := Id, name := Name, enable := Enable, description := Desc}) ->
    emqx_ctl:print("Rule{id=~ts, name=~ts, enabled=~ts, descr=~ts}\n", [
        Id, Name, Enable, Desc
    ]).

%% erlfmt-ignore
pretty_print_rule(Id0) ->
    %% TODO: namespace
    case emqx_rule_engine:get_rule(?global_ns, list_to_binary(Id0)) of
        {ok, #{id := Id, name := Name, description := Descr, enable := Enable,
               sql := SQL, created_at := CreatedAt, updated_at := UpdatedAt,
               actions := Actions}} ->
            emqx_ctl:print(
              "Id:\n  ~ts\n"
              "Name:\n  ~ts\n"
              "Description:\n  ~ts\n"
              "Enabled:\n  ~ts\n"
              "SQL:\n  ~ts\n"
              "Created at:\n  ~ts\n"
              "Updated at:\n  ~ts\n"
              "Actions:\n  ~s\n"
             ,[Id, Name, left_pad(Descr), Enable, left_pad(SQL),
               emqx_utils_calendar:epoch_to_rfc3339(CreatedAt, millisecond),
               emqx_utils_calendar:epoch_to_rfc3339(UpdatedAt, millisecond),
               [left_pad(format_action(A)) || A <- Actions]
              ]
             );
        _ ->
            ok
    end.

%% erlfmt-ignore
format_action(#{mod := Mod, func := Func, args := Args}) ->
    Name = emqx_rule_engine_api:printable_function_name(Mod, Func),
    io_lib:format("- Name:  ~s\n"
                  "  Type:  function\n"
                  "  Args:  ~p\n"
                 ,[Name, maps:without([preprocessed_tmpl], Args)]
                 );
format_action(BridgeChannelId) when is_binary(BridgeChannelId) ->
    io_lib:format("- Name:  ~s\n"
                  "  Type:  data-bridge\n"
                 ,[BridgeChannelId]
                 );
format_action({bridge, ActionType, ActionName, _Id}) ->
    io_lib:format("- Name:         ~p\n"
                  "  Action Type:  ~p\n"
                  "  Type:         data-bridge\n"
                 ,[ActionName, ActionType]
                 );
format_action({bridge_v2, ActionType, ActionName}) ->
    io_lib:format("- Name:         ~p\n"
                  "  Action Type:  ~p\n"
                  "  Type:         data-bridge\n"
                 ,[ActionName, ActionType]
                 ).

left_pad(Str) ->
    re:replace(Str, "\n", "\n  ", [global]).
