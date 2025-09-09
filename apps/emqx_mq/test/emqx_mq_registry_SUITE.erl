%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_mq_registry_SUITE).

-compile(nowarn_export_all).
-compile(export_all).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("snabbkaffe/include/snabbkaffe.hrl").

all() ->
    emqx_common_test_helpers:all(?MODULE).

init_per_suite(Config) ->
    Apps = emqx_cth_suite:start(
        [
            emqx,
            {emqx_mq, emqx_mq_test_utils:cth_config()}
        ],
        #{work_dir => emqx_cth_suite:work_dir(Config)}
    ),
    [{suite_apps, Apps} | Config].

end_per_suite(Config) ->
    ok = emqx_cth_suite:stop(?config(suite_apps, Config)).

%%--------------------------------------------------------------------
%% Test cases
%%--------------------------------------------------------------------

t_crud(_Config) ->
    _ = create_mq(<<"a/b/c">>),
    _ = create_mq(<<"a/b/#">>),
    _ = create_mq(<<"a/#">>),
    _ = create_mq(<<"a/+/d">>),
    ?assertMatch(
        [
            #{topic_filter := <<"a/b/c">>},
            #{topic_filter := <<"a/b/#">>},
            #{topic_filter := <<"a/#">>}
        ],
        emqx_mq_registry:match(<<"a/b/c">>)
    ),
    ?assertMatch(
        [
            #{topic_filter := <<"a/+/d">>},
            #{topic_filter := <<"a/#">>}
        ],
        emqx_mq_registry:match(<<"a/x/d">>)
    ),
    ok = emqx_mq_registry:delete(<<"a/#">>),
    ?assertMatch(
        [
            #{topic_filter := <<"a/+/d">>}
        ],
        emqx_mq_registry:match(<<"a/x/d">>)
    ),
    ok = emqx_mq_registry:delete_all(),
    ?assertMatch(
        [],
        emqx_mq_registry:match(<<"a/x/d">>)
    ).

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

create_mq(TopicFilter) ->
    emqx_mq_test_utils:create_mq(#{topic_filter => TopicFilter}).
