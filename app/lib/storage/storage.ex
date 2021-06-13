defmodule Proxy.Storage do
    def get_routes do
        %{
            "google" => [
                # 127.0.0.1:8080/cats -> https://google.com/imghp
                %{
                    method: "GET",
                    path: ["/cats", "/imghp"],
                    requirements: %{},
                    host: :google,
                },
            ],
            "robots" => [
                # 127.0.0.1:8080/some_name.png -> https://robohash.org/some_name.png
                %{
                    method: "GET",
                    path: ["/:name"],
                    requirements: %{
                        name: "\\w+?.(?:jpeg|png)"
                    },
                    host: :robohash,
                },
            ]
        }
    end
end
