defmodule Baud.ApiTest do
  use ExUnit.Case
  alias Baud.TestHelper

  test "api test" do
    tty0 = TestHelper.tty0
    tty1 = TestHelper.tty1
    {:ok, pid0} = Baud.start_link [device: tty0]
    {:ok, pid1} = Baud.start_link [device: tty1]

    Baud.write pid0, "01234\n56789\n98765\n43210"
    assert {:ok, "01234\n"} == Baud.readln pid1
    assert {:ok, "56789\n"} == Baud.readln pid1
    assert {:ok, "98765\n"} == Baud.readln pid1
    assert {:to, "43210"} == Baud.readln pid1

    Baud.write pid0, "01234\r56789\r98765\r43210"
    assert {:ok, "01234\r"} == Baud.readch pid1, "\r"
    assert {:ok, "56789\r"} == Baud.readch pid1, "\r"
    assert {:ok, "98765\r"} == Baud.readch pid1, "\r"
    assert {:to, "43210"} == Baud.readch pid1, "\r"

    Baud.write pid0, "01234\n56789\n98765\n43210"
    assert {:ok, "01234\n"} == Baud.readn pid1, 6
    assert {:ok, "56789\n"} == Baud.readn pid1, 6
    assert {:ok, "98765\n"} == Baud.readn pid1, 6
    assert {:to, "43210"} == Baud.readn pid1, 6
  end

end
