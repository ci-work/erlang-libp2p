-module(relay_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([
    all/0
    ,init_per_testcase/2
    ,end_per_testcase/2
]).

-export([
    basic/1
]).

%%--------------------------------------------------------------------
%% COMMON TEST CALLBACK FUNCTIONS
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @public
%% @doc
%%   Running tests for this suite
%% @end
%%--------------------------------------------------------------------
all() ->
    [basic].

%%--------------------------------------------------------------------
%% @public
%% @doc
%%   Special init config for test case
%% @end
%%--------------------------------------------------------------------
init_per_testcase(_, Config) ->
    test_util:setup(),
    lager:set_loglevel(lager_console_backend, info),
    Config.

%%--------------------------------------------------------------------
%% @public
%% @doc
%%   Special end config for test case
%% @end
%%--------------------------------------------------------------------
end_per_testcase(_, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
basic(_Config) ->
    SwarmOpts = [{libp2p_transport_tcp, [{nat, false}]}],
    {ok, ASwarm} = libp2p_swarm:start(a, SwarmOpts),
    {ok, BSwarm} = libp2p_swarm:start(b, SwarmOpts),
    {ok, RSwarm} = libp2p_swarm:start(r, SwarmOpts),

    ok = libp2p_swarm:listen(ASwarm, "/ip4/0.0.0.0/tcp/6600"),
    ok = libp2p_swarm:listen(BSwarm, "/ip4/0.0.0.0/tcp/6601"),
    ok = libp2p_swarm:listen(RSwarm, "/ip4/0.0.0.0/tcp/6602"),

    Version = "relaytest/1.0.0",
    libp2p_swarm:add_stream_handler(
        ASwarm
        ,Version
        ,{libp2p_framed_stream, server, [libp2p_stream_relay_test, self(), ASwarm]}
    ),
    libp2p_swarm:add_stream_handler(
        BSwarm
        ,Version
        ,{libp2p_framed_stream, server, [libp2p_stream_relay_test, self(), BSwarm]}
    ),
    libp2p_swarm:add_stream_handler(
        RSwarm
        ,Version
        ,{libp2p_framed_stream, server, [libp2p_stream_relay_test, self(), RSwarm]}
    ),
    [RAddress] = libp2p_swarm:listen_addrs(RSwarm),

    % NAT fails so A dials R to create a relay
    {ok, _} = libp2p_relay:dial(ASwarm, RAddress, []),
    % Waiting for connection
    timer:sleep(2000),

    % Testing relay address
    % Once relay is established get relay address from A's peerbook
    [_, ARelayAddress|_] = libp2p_swarm:listen_addrs(ASwarm),
    % B dials A via the relay address (so dialing R realy)
    {ok, _} = case libp2p_swarm:dial(BSwarm, ARelayAddress, Version) of
        {ok, Conn} ->
            libp2p_framed_stream:client(libp2p_stream_relay_test, Conn, []);
        Error ->
            ct:fail(Error)
    end,

    % libp2p_framed_stream:client(libp2p_stream_relay, Conn, [{swarm, BSwarm}]),
    timer:sleep(2000),

    ok.




%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------
