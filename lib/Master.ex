defmodule Modbus.Rtu.Master do
  use Agent

  @moduledoc """
    RTU module.

    ```elixir

    ```
  """
  alias Modbus.Rtu

  @doc """
  Starts the RTU server.

  `params` *must* contain a keyword list to be merged with the following defaults:
  ```elixir
  [
    device: nil,         #serial port name: "COM1", "ttyUSB0", "cu.usbserial-FTYHQD9MA"
    speed: 9600,       #either 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200
                         #win32 adds 14400, 128000, 256000
    config: "8N1",       #either "8N1", "7E1", "7O1"
  ]
  ```
  `opts` is optional and is passed verbatim to GenServer.

  Returns `{:ok, pid}`.
  ## Example
    ```
    Rtu.start_link([device: "COM8"])
    ```
  """
  def start_link(params, opts \\ [name: :mb]) do
    Agent.start_link(fn -> init(params) end, opts)
  end

  @sleep 1
  @to 800

  @doc """
    Stops the RTU server.

    Returns `:ok`.
  """
  def stop(pid) do
    Agent.get(
      pid,
      fn nid ->
        :ok = Sniff.close(nid)
      end,
      @to
    )

    Agent.stop(pid)
  end

  def exec(pid, cmd, timeout \\ @to) do
    Agent.get(
      pid,
      fn nid ->
        now = now()
        dl = now + timeout
        request = Rtu.pack_req(cmd)
        length = Rtu.res_len(cmd)
        :ok = Sniff.write(nid, request)
        response = read_n(nid, [], 0, length, dl)
        :timer.sleep(1)

        case byte_size(response) do
          ^length ->
            values = Rtu.parse_res(cmd, response)

            case values do
              :error -> {:error, "[Modbus.Rtu] -> wrong response #{inspect(response)}"}
              nil -> :ok
              _ -> {:ok, values}
            end

          _ ->
            {:error, "[Modbus.Master] -> wrong response #{inspect(response)}"}
        end
      end,
      2 * timeout
    )
  end

  defp init(params) do
    device = Keyword.fetch!(params, :device)
    speed = Keyword.get(params, :speed, 9600)
    config = Keyword.get(params, :config, "8N1")
    {:ok, nid} = Sniff.open(device, speed, config)
    nid
  end

  defp read_n(nid, iol, size, count, dl) do
    case size >= count do
      true ->
        flat(iol)

      false ->
        {:ok, data} = Sniff.read(nid)

        case data do
          <<>> ->
            :timer.sleep(@sleep)
            now = now()

            case now > dl do
              true -> flat(iol)
              false -> read_n(nid, iol, size, count, dl)
            end

          _ ->
            read_n(nid, [data | iol], size + byte_size(data), count, dl)
        end
    end
  end

  defp flat(list) do
    reversed = Enum.reverse(list)
    :erlang.iolist_to_binary(reversed)
  end

  defp now(), do: :os.system_time(:milli_seconds)
  # defp now(), do: :erlang.monotonic_time :milli_seconds
end
