# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


def expected_output(ui_in_val):
    b3 = (ui_in_val >> 3) & 1
    b2 = (ui_in_val >> 2) & 1
    b1 = (ui_in_val >> 1) & 1
    b0 = ui_in_val & 1
    inputs = [b3, b2, b1, b0]

    w_VL = [1, -1, 1, -1]
    w_VR = [-1, 1, -1, 1]
    w_HT = [1, 1, -1, -1]
    w_HB = [-1, -1, 1, 1]

    s_VL = sum(i * w for i, w in zip(inputs, w_VL))
    s_VR = sum(i * w for i, w in zip(inputs, w_VR))
    s_HT = sum(i * w for i, w in zip(inputs, w_HT))
    s_HB = sum(i * w for i, w in zip(inputs, w_HB))

    max_v = max(s_VL, s_VR)
    max_h = max(s_HT, s_HB)

    prediction = 1 if max_v >= max_h else 0

    max_v_3b = max_v & 0x07
    max_h_3b = max_h & 0x07

    return (max_h_3b << 4) | (max_v_3b << 1) | prediction


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start TinyNPU Testbench")

    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)

    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    dut._log.info("Testing all 16 input combinations")

    for i in range(16):
        dut.ui_in.value = i
        await ClockCycles(dut.clk, 2)

        actual = int(dut.uo_out.value)
        expected = expected_output(i)

        pred_act = actual & 0x01
        max_v_act = (actual >> 1) & 0x07
        max_h_act = (actual >> 4) & 0x07

        dut._log.info(
            f"Input: {i:04b} ({i:2d}) | Output: 0x{actual:02X} | "
            f"Pred: {pred_act} | MaxV: {max_v_act} | MaxH: {max_h_act}"
        )

        assert actual == expected, (
            f"Mismatch for input {i:04b}: got 0x{actual:02X}, expected 0x{expected:02X}"
        )

    dut._log.info("ALL 16 TESTS PASSED SUCCESSFULLY!")
