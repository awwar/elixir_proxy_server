defmodule Proxy.Application do
    use Application

    import Supervisor.Spec, warn: false

    def start(_type, _args) do
        children = [
            {
                Plug.Cowboy,
                scheme: :http,
                plug: Proxy.Router,
                options: [
                    port: 8080
                ]
            }
        ]

        Proxy.HandlerCompiler.compile(Proxy.Storage.get_routes())

        Supervisor.start_link children, [strategy: :one_for_one, name: Proxy.Supervisor]
    end
end
