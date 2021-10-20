defmodule EthereumJSONRPC.Encoder do
  @moduledoc """
  Deals with encoding and decoding data to be sent to, or that is
  received from, the blockchain.
  """

  alias ABI.TypeDecoder

  @doc """
  Given a function selector and a list of arguments, returns their encoded versions.

  This is what is expected on the Json RPC data parameter.
  """
  @spec encode_function_call(%ABI.FunctionSelector{}, [term()]) :: String.t()
  def encode_function_call(function_selector, args) do
    parsed_args = parse_args(args)

    encoded_args =
      function_selector
      |> ABI.encode(parsed_args)
      |> Base.encode16(case: :lower)

    "0x" <> encoded_args
  end

  defp parse_args(args) do
    args
    |> Enum.map(fn
      <<"0x", hexadecimal_digits::binary>> ->
        Base.decode16!(hexadecimal_digits, case: :mixed)

      item ->
        if is_list(item) do
          item
          |> Enum.map(fn el ->
            <<"0x", hexadecimal_digits::binary>> = el
            Base.decode16!(hexadecimal_digits, case: :mixed)
          end)
        else
          item
        end
    end)
  end

  @doc """
  Given a result from the blockchain, and the function selector, returns the result decoded.
  """
  def decode_result(_, _, leave_error_as_map \\ false)

  @spec decode_result(map(), %ABI.FunctionSelector{} | [%ABI.FunctionSelector{}]) ::
          {String.t(), {:ok, any()} | {:error, String.t() | :invalid_data}}
  def decode_result(%{error: %{code: code, data: data, message: message}, id: id}, _selector, leave_error_as_map) do
    if leave_error_as_map do
      {id, {:error, %{code: code, message: message, data: data}}}
    else
      {id, {:error, "(#{code}) #{message} (#{data})"}}
    end
  end

  def decode_result(%{error: %{code: code, message: message}, id: id}, _selector, leave_error_as_map) do
    if leave_error_as_map do
      {id, {:error, %{code: code, message: message}}}
    else
      {id, {:error, "(#{code}) #{message}"}}
    end
  end

  def decode_result(result, selectors, leave_error_as_map) when is_list(selectors) do
    selectors
    |> Enum.map(fn selector ->
      try do
        decode_result(result, selector)
      rescue
        _ -> :error
      end
    end)
    |> Enum.find(fn decode ->
      case decode do
        {_id, {:ok, _}} -> true
        _ -> false
      end
    end)
  end

  def decode_result(%{id: id, result: result}, function_selector, leave_error_as_map) do
    types_list = List.wrap(function_selector.returns)

    decoded_data =
      result
      |> String.slice(2..-1)
      |> Base.decode16!(case: :lower)
      |> TypeDecoder.decode_raw(types_list)
      |> Enum.zip(types_list)
      |> Enum.map(fn
        {value, :address} -> "0x" <> Base.encode16(value, case: :lower)
        {value, :string} -> unescape(value)
        {value, _} -> value
      end)

    {id, {:ok, decoded_data}}
  rescue
    MatchError ->
      {id, {:error, :invalid_data}}
  end

  def unescape(data) do
    if String.starts_with?(data, "\\x") do
      charlist = String.to_charlist(data)
      erlang_literal = '"#{charlist}"'
      {:ok, [{:string, _, unescaped_charlist}], _} = :erl_scan.string(erlang_literal)
      List.to_string(unescaped_charlist)
    else
      data
    end
  end
end
