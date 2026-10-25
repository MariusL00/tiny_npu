<!---
This file is used to generate your project datasheet. Please fill in the information below and delete any unused sections.
You can also include images in this folder and reference them in the markdown. Each image must be less than 512 kb in size.
-->
## How it works

The TinyNPU 3x3 is an explainable, purely combinational hardware Neural Processing Unit designed for educational purposes. It classifies 3x3 binary pixel grids into four categories: Horizontal lines, Vertical lines, and two Diagonals.

Instead of storing synaptic weights in volatile memory, the weights (+1 for target pixels, -1 for background noise) are physically hardwired directly into the silicon using spatial Adder Trees. This architecture allows the NPU to compute the MAC (Multiply-Accumulate) operations instantaneously without requiring a clock signal. 

A hardware Max Pooling layer (a tree of signed comparators) evaluates the results to select the highest score. If the maximum score meets the internal activation threshold (set to 2) and there are no ties, the NPU validates the shape.

To make the AI's "thought process" transparent, the 8-bit output bus is split into two telemetry data points:
* **The 3 Least Significant Bits (LSB, uo_out[2:0]):** Output the Prediction ID.
* **The 5 Most Significant Bits (MSB, uo_out[7:3]):** Output the exact winning MAC Score as a signed Two's Complement integer (from -16 to +15).

## How to test

1. Provide a 3x3 binary image using the input pins: pixels 0 to 7 on `ui_in[7:0]` and the 9th pixel on `uio_in[0]`.
2. The logic is combinational; the result is immediately available on `uo_out[7:0]` after the gate propagation delay (~2.5ns).
3. Decode the 3 LSBs using a bitwise AND mask (`val & 0x07`) to get the detected shape ID:
   * `0` = Unknown / Noise (Threshold not met or tie)
   * `1` = Horizontal Line (-)
   * `2` = Vertical Line (|)
   * `3` = Diagonal 1 (\)
   * `4` = Diagonal 2 (/)
4. Decode the 5 MSBs by shifting the value right by 3 bits (`val >> 3`). This reveals the internal MAC score, demonstrating the network's confidence level before the final classification.

## External hardware

To fully exploit the educational aspect of this chip, the following external hardware is recommended:
* A microcontroller (STM32, ESP32, or Arduino) to automatically feed pixel arrays, read the 8-bit output port, and apply the bitshift masks.
* An I2C/SPI OLED display to visualize the 3x3 input matrix alongside the real-time Prediction ID and the internal MAC score computed by the ASIC.
* Alternatively, a 9-pin DIP switch block and a set of LEDs can be used for manual, clock-less logic verification.
