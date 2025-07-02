`timescale 1ns/1ps

module tb_topStrassen2;

  // Clock and reset
  logic clk = 0;
  logic reset = 0;
  logic start = 0;
  logic [3:0] mode;

  // Outputs from DUT
  logic done;
  logic [3:0] stateMM;
  logic [11:0] memC_0, memC_1, memC_2, memC_3, memC_4, memC_5, memC_6, memC_7,
                    memC_8, memC_9, memC_10, memC_11, memC_12, memC_13, memC_14, memC_15,
                    memC_16, memC_17, memC_18, memC_19, memC_20, memC_21, memC_22, memC_23,
                    memC_24, memC_25, memC_26, memC_27, memC_28, memC_29, memC_30, memC_31,
                    memC_32, memC_33, memC_34, memC_35, memC_36, memC_37, memC_38, memC_39,
                    memC_40, memC_41, memC_42, memC_43, memC_44, memC_45, memC_46, memC_47,
                    memC_48, memC_49, memC_50, memC_51, memC_52, memC_53, memC_54, memC_55,
                    memC_56, memC_57, memC_58, memC_59, memC_60, memC_61, memC_62, memC_63;
  logic we_tb, ldmemAB_tb, ldBF_tb, ldComb2_tb, ldSlice_tb, ldCalc1_tb, ldCalc2_tb, ldComb1_tb, clrAll_tb;
  logic [3:0] addr_tb;
    
  // Clock generation: 100MHz (10ns period)
  always #5 clk = ~clk;

  // Instantiate DUT
  topStrassen dut (.*);

  // === Simulation control ===
  initial begin

    $display("=== Strassen Matrix Multiplication Testbench Start ===");

    // Apply reset
    reset = 1;
    #20;
    reset = 0;

    // ------------------------
    // Test Case: 2x2
    // ------------------------
    $display("\n=== Testing 2x2 ===");
    mode = 4'd2;
    start = 1;
    #10 start=0;
    wait(done == 1);
    #20;

    // ------------------------
    // Test Case: 4x4
    // ------------------------
    $display("\n=== Testing 4x4 ===");
    mode = 4'd4;
    start = 1;
    #10 start=0;

    wait(done == 1);
    #20;

    // ------------------------
    // Test Case: 8x8
    // ------------------------
    $display("\n=== Testing 8x8 ===");
    mode = 4'd8;
    start = 1;
    #10 start=0;

    wait(done == 1);
    #50;

    $display("\n=== Strassen Matrix Multiplication Testbench Finished ===");
    $finish;
  end

endmodule
