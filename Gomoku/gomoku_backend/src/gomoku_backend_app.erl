-module(gomoku_backend_app).
-behaviour(application).

%% --- Application Callbacks ---
-export([start/2, stop/1]).

%% This is the absolute starting point of our application.
start(_StartType, _StartArgs) ->
    %% For now, we just tell our main Supervisor to wake up.
    %% In the next step, we will inject the Cowboy WebSocket routing here!
    gomoku_backend_sup:start_link().

stop(_State) ->
    ok.