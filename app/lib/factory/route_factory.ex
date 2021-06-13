defmodule Proxy.RouteFactory do
    def create(method, path, reqs, host) do
        [inner, outer] = case path do
            [a, b] -> [a, b]
            [a] -> [a, a]
        end

        method = method
                 |> String.upcase

        atomic_path = inner
                      |> String.split("/")
                      |> Enum.filter(fn i -> i !== ""  end)
                      |> Enum.map(fn i -> atom_string_to_atoms(i) end)

        pseudonyms = atomic_path
                     |> Enum.filter(fn i -> is_atom(i) end)
                     |> Enum.with_index
                     |> Enum.map(fn {i, n} -> {i, String.to_atom("var#{n}")} end)

        pseudonyms_path = atomic_path
                          |> Enum.map(fn i -> get_pseudonym(i, pseudonyms) end)

        inner_path = pseudonyms_path
                     |> Enum.map(fn i -> get_partition(i) end)

        outer_path = outer
                     |> String.split("/")
                     |> Enum.filter(fn i -> i !== ""  end)
                     |> Enum.map(fn i -> atom_string_to_atoms(i) end)
                     |> Enum.map(fn i -> get_pseudonym(i, pseudonyms) end)
                     |> filter_from_list()
                     |> append_host(host)

        pseudonyms_reqs = reqs
                          |> Enum.map(fn {k, v} -> {get_pseudonym(k, pseudonyms), v} end)
                          |> create_filter

        key = pseudonyms_path
              |> Enum.join
        key = method <> ":" <> key

        %{
            key: key,
            method: method,
            inner_path: inner_path,
            outer_path: outer_path,
            reqs: pseudonyms_reqs
        }
    end

    defp filter_from_list(list) do
        add_partition_to_filter(list)
    end

    defp add_partition_to_filter(list) when length(list) == 0 do
        "/"
    end

    defp add_partition_to_filter([value | _] = list) when length(list) == 1 do
        get_wrapped_partition(value)
    end

    defp add_partition_to_filter([value | rest]) do
        {
            :<>,
            [context: Proxy.Handler, import: Kernel],
            [get_wrapped_partition(value), add_partition_to_filter(rest)]
        }
    end

    defp get_wrapped_partition(value) do
        value
        |> get_partition
        |> wrap_partition
    end

    defp get_partition(value) when is_atom(value) do
        {value, [], Proxy.Handler}
    end

    defp get_partition(value) do
        value
    end

    defp wrap_partition(value) when is_binary(value) do
        "/" <> value
    end

    defp wrap_partition(value) do
        {:<>, [context: Proxy.Handler, import: Kernel], ["/", value]}
    end

    defp atom_string_to_atoms(":" <> value) do
        String.to_atom(value)
    end

    defp atom_string_to_atoms(value) do
        value
    end

    defp get_pseudonym(value, pseudonyms) do
        pseudonyms[value]
    rescue
        _ -> value
    end

    defp create_filter([{k, v} | rest]) when length(rest) === 0 do
        {
            :=~,
            [],
            [
                {k, [], Proxy.Handler},
                {:sigil_r, [delimiter: "\"", context: Proxy.Handler, import: Kernel], [{:<<>>, [], [v]}, []]}
            ]
        }
    end

    defp create_filter([{k, v} | rest]) do
        {
            :and,
            [],
            [
                create_filter([{k, v}]),
                create_filter(rest)
            ]
        }
    end

    defp create_filter(_) do
        true
    end

    defp append_host(value, host) do
        {:<>, [context: Proxy.Handler, import: Kernel], [host, value]}
    end
end
