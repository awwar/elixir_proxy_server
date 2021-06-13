defmodule Proxy.Router do
    use Plug.Router

    plug :match
    plug :dispatch

    match _ do
        Proxy.Handler.handle(conn.method, conn.path_info, conn)
    end
end
