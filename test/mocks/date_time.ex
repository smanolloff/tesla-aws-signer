defmodule Mocks.DateTime do
  use Mocks.Base, state: :unset

  def with_time(%DateTime{} = time, func) do
    old_time = get_state()

    try do
      set_state(time)
      func.()
    after
      set_state(old_time)
    end
  end

  def utc_now do
    get_state()
  end

  #
  # private
  #

  #################

  def _get_state(state), do: state

  def _set_state(_state, new_state), do: new_state
end
