%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-ifndef(EMQX_MQ_INTERNAL_HRL).
-define(EMQX_MQ_INTERNAL_HRL, true).

-define(VIA_GPROC(Id), {via, gproc, {n, l, Id}}).

-define(MQ_HEADER_MESSAGE_ID, mq_msg_id).
-define(MQ_HEADER_SUBSCRIBER_ID, mq_sub_id).

-define(MQ_ACK, 0).
-define(MQ_NACK, 1).

-define(MQ_MESSAGE(MESSAGE), {mq_message, MESSAGE}).
-define(MQ_PING_SUBSCRIBER(SUBSCRIBER_REF), {mq_ping, SUBSCRIBER_REF}).
-define(MQ_SUB_INFO(SUBSCRIBER_REF, MESSAGE), {mq_sub_info, SUBSCRIBER_REF, MESSAGE}).

-define(MQ_PAYLOAD_DB, mq_payload).
-define(MQ_PAYLOAD_DB_APPEND_RETRY, 5).

-define(MQ_PAYLOAD_DB_LTS_SETTINGS, #{
    %% "topic/TOPIC/key/СOMPACTION_KEY"
    lts_threshold_spec => {simple, {100, 0, 100, 0, 100}}
}).
-define(MQ_PAYLOAD_DB_TOPIC(MQ_TOPIC, COMPACTION_KEY), [
    <<"topic">>, MQ_TOPIC, <<"key">>, COMPACTION_KEY
]).

%% TODO
%% make configurable, increase

-define(MQ_CONSUMER_MAX_BUFFER_SIZE, 10).
-define(MQ_CONSUMER_MAX_UNACKED, 5).

%% TODO
%% configurable

%% 10 seconds
-define(DEFAULT_SUBSCRIBER_TIMEOUT, 10000).
%% 10 seconds
-define(DEFAULT_CONSUMER_TIMEOUT, 10000).
%% 5 seconds
-define(DEFAULT_PING_INTERVAL, 5000).

-endif.
