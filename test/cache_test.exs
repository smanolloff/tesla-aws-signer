defmodule AwsSigner.CacheTest do
  alias AwsSigner.Cache
  use ExUnit.Case

  setup do
    Cache.start_link()
    :ok
  end

  test "fetch/2" do
    assert Cache.fetch("k1") == :miss
    assert Cache.fetch("k1", fn -> {:ok, "v1"} end) == {:miss, {"v1", nil}}
    assert Cache.fetch("k1", fn -> {:ok, "v2"} end) == {:hit, {"v1", nil}}
    assert Cache.fetch("k2", fn -> {:ok, "v3"} end) == {:miss, {"v3", nil}}
    assert Cache.fetch("k1", fn -> {:ok, "v4"} end) == {:hit, {"v1", nil}}

    # future timestamp
    t1 = DateTime.to_unix(~U[2050-01-01T00:00:00Z], :millisecond)
    assert Cache.fetch("k3", fn -> {:ok, "v5", t1} end) == {:miss, {"v5", t1}}
    assert Cache.fetch("k3") == {:hit, {"v5", t1}}

    # expired timestamp
    t2 = DateTime.to_unix(~U[2000-01-01T00:00:00Z], :millisecond)
    assert Cache.fetch("k4", fn -> {:ok, "v6", t2} end) == {:miss, {"v6", t2}}
    assert Cache.fetch("k4") == :miss

    # Bad fallback return
    assert Cache.fetch("k5", fn -> "v7" end) == {:miss, :error, "v7"}
    assert Cache.fetch("k5") == :miss

    assert Agent.get(Cache, & &1) == %{
      "k1" => {"v1", nil},
      "k2" => {"v3", nil},
      "k3" => {"v5", t1},
      "k4" => {"v6", t2}
    }
  end

  test "put/2" do
    assert Cache.put("k1", "v1") == {"v1", nil}
    assert Cache.put("k2", "v2") == {"v2", nil}
    assert Cache.put("k3", "v3") == {"v3", nil}
    assert Cache.put("k1", "v4") == {"v4", nil}

    t = DateTime.to_unix(~U[2000-01-01T00:00:00Z])
    assert Cache.put("k4", "v5", t) == {"v5", t}

    assert Agent.get(Cache, & &1) == %{
      "k1" => {"v4", nil},
      "k2" => {"v2", nil},
      "k3" => {"v3", nil},
      "k4" => {"v5", t}
    }
  end

  test "delete/1" do
    Cache.put("k1", "v1")
    assert :ok = Cache.delete("k1")
    assert Agent.get(Cache, & &1) == %{}
  end
end
