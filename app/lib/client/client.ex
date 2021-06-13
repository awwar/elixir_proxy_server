defmodule Proxy.Client do
    def proxy(url, conn) do
        query_string = conn.query_string
        path = url <> case query_string do
            "" -> ""
            _ -> "?" <> query_string
               end

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        req_headers = Enum.filter(conn.req_headers, fn {k, _} -> k !== "host" end)

        %HTTPoison.AsyncResponse{id: id} = HTTPoison.request!(
            conn.method,
            path,
            body,
            req_headers,
            stream_to: self()
        )

        %{code: status_code, headers: response_headers} = pre_load(id, %{code: nil, headers: nil})

        conn
        |> set_headers(response_headers)
        |> Plug.Conn.send_chunked(status_code)
        |> async_download(id)
    end

    defp set_headers(conn, headers) when length(headers) === 0 do
        conn
    end

    defp set_headers(conn, [{k, v} | rest]) do
        conn
        |> Plug.Conn.put_resp_header(k, v)
        |> set_headers(rest)
    end

    defp pre_load(id, result) do
        receive do
            %HTTPoison.AsyncStatus{code: status_code, id: ^id} ->
                pre_load(id, %{result | code: status_code})

            %HTTPoison.AsyncHeaders{headers: headers, id: ^id} ->
                %{result | headers: Enum.filter(headers, fn {k, _} -> k !== "Transfer-Encoding" end)}
        end
    end

    defp async_download(conn, id) do
        receive do
            %HTTPoison.AsyncChunk{chunk: chunk, id: ^id} ->
                {:ok, conn} = conn
                              |> Plug.Conn.chunk(chunk)

                async_download(conn, id)

            %HTTPoison.AsyncEnd{id: ^id} ->
                conn
        end
    end
end
