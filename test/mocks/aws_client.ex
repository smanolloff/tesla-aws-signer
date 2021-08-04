defmodule Mocks.AwsClient do
  use Mocks.Base, state: {:unset, :unset}

  def with_response(resp, func) do
    old_state = get_state()

    try do
      set_resp(resp)
      res = func.()
      {get_req(), res}
    after
      set_state(old_state)
    end
  end

  def call_mock(args) do
    set_req(args)
    get_resp()
  end

  def get!(url), do: call_mock([url])
  def post!(url, body, opts), do: call_mock([url, body, opts])

  #
  # private
  #

  def get_req(), do: get_state() |> elem(0)

  def get_resp() do
    {req, resp} = get_state()

    # Emulate a race condition:
    # a code executes after the request is sent,
    # but before the response is received
    if is_function(resp), do: resp.(req), else: resp
  end

  def set_req(req) do
    {_, resp} = get_state()
    set_state({req, resp})
  end

  def set_resp(resp) do
    {req, _} = get_state()
    set_state({req, resp})
  end

  #################

  def _get_state(state), do: state

  def _set_state(_state, new_state), do: new_state
end
