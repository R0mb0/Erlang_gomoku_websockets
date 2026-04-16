-module(gomoku_backend_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    %% 1. Define Cowboy Routes. Traffic to ws://localhost:8080/ws goes to gomoku_ws_handler
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/ws", gomoku_ws_handler, []}
        ]}
    ]),

    %% 2. Start the Cowboy HTTP/WebSocket server on port 8080
    {ok, _} = cowboy:start_clear(http_listener,
        [{port, 8080}],
        #{env => #{dispatch => Dispatch}}
    ),

    %% 3. Start our Supervisor (which starts Tuple Space and Gomoku Server)
    gomoku_backend_sup:start_link().

stop(_State) ->
    ok.