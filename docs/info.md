## How it works

TinyNPU Lab is a fully combinatorial, application-specific integrated circuit (ASIC) that acts as a hardware neural network accelerator. It is designed to classify a 2x2 binary pixel grid into two categories: Vertical Line (Class A) or Horizontal Line (Class B). 

The architecture implements a complete inference datapath directly in silicon without requiring a CPU or software execution:
* **Input Layer:** 4 binary pixels representing a 2x2 grid.
* **Feature Extraction (Layer 1):** 4 distinct neurons calculate the correlation between the input and four specific patterns (Left Vertical, Right Vertical, Top Horizontal, Bottom Horizontal) using hardcoded synaptic weights (+1 and -1). The Multiply-Accumulate (MAC) operations are synthesized purely using combinatorial adders and two's complement arithmetic.
* **Max Pooling (Layer 2):** Two hardware comparators and multiplexers aggregate the feature scores to extract the maximum Vertical score (`Max_V`) and maximum Horizontal score (`Max_H`).
* **Classification (Layer 3):** A final combinatorial comparator evaluates if `Max_V >= Max_H`. If true, the network predicts a vertical dominance.

## How to test

The design is completely combinatorial and evaluates instantly without a clock signal.

1. **Set the inputs:** Use the 4 input pins (`ui_in[3:0]`) to draw a 2x2 binary pattern. For example, setting `ui_in[3]=1`, `ui_in[2]=0`, `ui_in[1]=1`, `ui_in[0]=0` generates a left vertical line.
2. **Read the prediction:** The primary decision output is on `uo_out[0]`. A `1` indicates a Vertical pattern, and a `0` indicates a Horizontal pattern. 
3. **Read internal NPU scores:** To prove the silicon is performing the neural computations, the internal 3-bit signed scores (two's complement, ranging from -2 to +2) are exported to the output pins:
   * `uo_out[3:1]` outputs the `Max_V` score.
   * `uo_out[6:4]` outputs the `Max_H` score.

## External hardware

To fully demonstrate the TinyNPU Lab project, the following external hardware is recommended:
* **Input:** A 4-position DIP switch or a custom button matrix to generate the 2x2 pixel grid.
* **Basic Output:** 1 LED connected to `uo_out[0]` to visualize the predicted class.
* **Advanced Interface (Optional):** A microcontroller (e.g., STM32, ESP32, or the onboard RP2040) connected to an OLED display. The MCU reads the 8-bit output bus, decodes the two's complement 3-bit scores, and displays the NPU's internal mathematical calculations in real-time to the user.
