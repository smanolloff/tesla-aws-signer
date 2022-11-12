defmodule Mocks.Cache do
  use Mocks.Base, state: %{}

  def with_response(called_func, result, func) do
    old_state = get_state(called_func)

    try do
      set_resp(called_func, result)
      res = func.()
      {get_call_args(called_func), res}
    after
      set_state({called_func, old_state})
    end
  end

  def fetch(cache_name, key, fallback_fn) do
    set_call_args(:fetch, [cache_name, key, fallback_fn])
    get_result(:fetch)
  end

  def expire_at(cache_name, key, epoch_ms) do
    set_call_args(:expire_at, [cache_name, key, epoch_ms])
    get_result(:expire_at)
  end

  def expire(cache_name, key, epoch_ms) do
    set_call_args(:expire, [cache_name, key, epoch_ms])
    get_result(:expire)
  end

  #
  # private
  #

  def get_call_args(called_func),
    do: get_state(called_func) |> elem(0)

  def get_result(called_func) do
    {call_args, result} = get_state(called_func)

    # The result can be a function - in this case, call it
    if is_function(result),
      do: result.(call_args),
      else: result
  end

  def set_call_args(called_func, call_args) do
    {_, result} = get_state(called_func)
    set_state({called_func, {call_args, result}})
  end

  def set_resp(called_func, result) do
    {call_args, _} = get_state(called_func)
    set_state({called_func, {call_args, result}})
  end

  #################

  def _get_state(state, called_func) do
    Map.get(state, called_func, {:unset, :unset})
  end

  def _set_state(state, {called_func, func_state}) do
    Map.put(state, called_func, func_state)
  end
end
