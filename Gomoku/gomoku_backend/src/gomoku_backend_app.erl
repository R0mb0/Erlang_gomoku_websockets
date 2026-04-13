%%%-------------------------------------------------------------------
%% @doc gomoku_backend public API
%% @end
%%%-------------------------------------------------------------------

-module(gomoku_backend_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    gomoku_backend_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
