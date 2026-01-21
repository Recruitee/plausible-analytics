defmodule Plausible.Session.SaltsTest do
  use Plausible.DataCase
  alias Plausible.Session.Salts

  describe "fetch/0" do
    test "returns current and previous salts which are loaded during initialization" do
      assert %{previous: _prev, current: current} = Salts.fetch()

      assert current
    end
  end

  describe "rotate/0" do
    test "generates a new current salt" do
      %{current: current} = Salts.fetch()

      Salts.rotate()

      %{current: new} = Salts.fetch()
      assert new != current
    end

    test "moves current salt to previous" do
      %{current: current} = Salts.fetch()

      Salts.rotate()

      %{previous: previous} = Salts.fetch()
      assert previous == current
    end

    test "new salt is a 16-byte binary" do
      Salts.rotate()

      %{current: current} = Salts.fetch()
      assert is_binary(current)
      assert byte_size(current) == 16
    end

    test "persists new salt to database" do
      Salts.rotate()

      %{current: salt} = Salts.fetch()

      assert Repo.exists?(from s in "salts", where: s.salt == ^salt)
    end
  end
end
