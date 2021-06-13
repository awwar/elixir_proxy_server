defmodule Proxy.HandlerCompiler do
    def compile(routes) do
        services = parse_env(System.get_env() |> Map.to_list())

        if services === [] do
            exit "Services list is empty!"
        end

        routes
        |> Enum.map(fn {_, v} -> v end)
        |> List.flatten
        |> Enum.map(
               fn %{method: method, path: path, requirements: reqs, host: host} ->
                   Proxy.RouteFactory.create(method, path, reqs, services[host])
               end
           )
        |> Enum.map_reduce(
               %{},
               fn x, acc ->
                   key = x.key
                   val = if Map.has_key?(acc, key) do
                       value = Map.get(acc, key)
                       value ++ [x]
                   else
                       [x]
                   end

                   {x, Map.put(acc, key, val)}
               end
           )
        |> then(fn {_, r} -> r end)
        |> Enum.map(
               fn {_, route} ->
                   method = Enum.at(route, 0).method
                   inner_path = Enum.at(route, 0).inner_path
                   cond_body = route
                               |> Enum.map(
                                      fn %{reqs: reqs, outer_path: outer_path} ->
                                          [cases] = quote do
                                              unquote(reqs) ->
                                                  Proxy.Handler.send(
                                                      unquote(outer_path),
                                                      unquote({:conn, [], Proxy.Handler})
                                                  )
                                          end

                                          cases
                                      end
                                  )

                   cond_body = cond_body ++ quote do
                       true -> Plug.Conn.resp(unquote({:conn, [], Proxy.Handler}), 404, "Not found!")
                               end


                   quote do
                       def unquote(:handle)(
                               unquote(method),
                               unquote(inner_path),
                               unquote({:conn, [], Proxy.Handler})
                           ) do
                           cond do
                               unquote(cond_body)
                           end
                       end
                   end
               end
           )
        |> then(
               fn body ->
                   quote(
                       do: defmodule Proxy.Handler do
                           unquote({:__block__, [], body})

                           def handle(_, _, conn) do
                               Plug.Conn.resp(conn, 404, "Not found!")
                           end

                           def send(url, conn) do
                               Proxy.Client.proxy(url, conn)
                           end
                       end
                   )
               end
           )
#        |> then(&IO.puts(Macro.to_string(&1)))
        |> Code.eval_quoted()
    end

    defp parse_env(envs, acc \\ [])

    defp parse_env([], acc), do: acc

    defp parse_env([{"SERVICES_HOSTS_" <> k, v} | rest], acc), do: parse_env(rest, acc ++ [{to_downcase_atom(k), v}])

    defp parse_env([_ | rest], acc), do: parse_env(rest, acc)

    defp to_downcase_atom(key),
         do: key
             |> String.downcase()
             |> String.to_atom()

end
