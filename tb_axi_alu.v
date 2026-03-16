// tb_axi_alu.v
// Directed self-checking testbench for axi_alu_top
// Tests: ADD, SUB, AND, OR, overflow detection

`timescale 1ns/1ps

module tb_axi_alu;

    // -------------------------------------------------------
    // Parameters & clock
    // -------------------------------------------------------
    parameter CLK_PERIOD = 10;  // 100 MHz

    reg        aclk    = 0;
    reg        aresetn = 0;
    always #(CLK_PERIOD/2) aclk = ~aclk;

    // -------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------
    reg  [4:0]  s_axi_awaddr;
    reg         s_axi_awvalid;
    wire        s_axi_awready;

    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;

    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;

    reg  [4:0]  s_axi_araddr;
    reg         s_axi_arvalid;
    wire        s_axi_arready;

    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    // -------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------
    axi_alu_top dut (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready)
    );

    // -------------------------------------------------------
    // Tracking
    // -------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // -------------------------------------------------------
    // Task: AXI Write (address + data, wait for B response)
    // -------------------------------------------------------
    task axi_write;
        input [4:0]  addr;
        input [31:0] data;
        begin
            // Drive AW
            @(posedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hF;
            s_axi_wvalid  <= 1'b0;  // data not yet valid

            // Wait for AW handshake
            @(posedge aclk);
            while (!s_axi_awready) @(posedge aclk);
            s_axi_awvalid <= 1'b0;

            // Drive W
            s_axi_wvalid <= 1'b1;
            @(posedge aclk);
            while (!s_axi_wready) @(posedge aclk);
            s_axi_wvalid <= 1'b0;

            // Wait for B response
            s_axi_bready <= 1'b1;
            @(posedge aclk);
            while (!s_axi_bvalid) @(posedge aclk);
            @(posedge aclk);
            s_axi_bready <= 1'b0;
        end
    endtask

    // -------------------------------------------------------
    // Task: AXI Read (returns data in rdata_out)
    // -------------------------------------------------------
    task axi_read;
        input  [4:0]  addr;
        output [31:0] rdata_out;
        begin
            @(posedge aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            @(posedge aclk);
            while (!s_axi_arready) @(posedge aclk);
            s_axi_arvalid <= 1'b0;

            while (!s_axi_rvalid) @(posedge aclk);
            rdata_out     = s_axi_rdata;
            @(posedge aclk);
            s_axi_rready  <= 1'b0;
        end
    endtask

    // -------------------------------------------------------
    // Task: Check result with label
    // -------------------------------------------------------
    task check;
        input [31:0] got;
        input [31:0] expected;
        input [127:0] label;
        begin
            if (got === expected) begin
                $display("PASS  [%s]  got=0x%08X", label, got);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL  [%s]  got=0x%08X  expected=0x%08X", label, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------
    reg [31:0] rd_data;

    initial begin
        // Init all master signals
        s_axi_awaddr  = 0; s_axi_awvalid = 0;
        s_axi_wdata   = 0; s_axi_wstrb   = 0; s_axi_wvalid = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = 0; s_axi_arvalid = 0;
        s_axi_rready  = 0;

        // Reset for 5 cycles
        repeat(5) @(posedge aclk);
        aresetn = 1;
        repeat(2) @(posedge aclk);

        $display("--------------------------------------------");
        $display(" AXI4-Lite ALU Peripheral Testbench");
        $display("--------------------------------------------");

        // --------------------------------------------------
        // Test 1: ADD  (25 + 17 = 42)
        // --------------------------------------------------
        $display("\n[TEST 1] ADD: 25 + 17 = 42");
        axi_write(5'h00, 32'd25);   // OPERAND_A
        axi_write(5'h04, 32'd17);   // OPERAND_B
        axi_write(5'h08, 32'd0);    // OP_SEL = ADD
        axi_read (5'h0C, rd_data);  // RESULT
        check(rd_data, 32'd42, "ADD result");
        axi_read (5'h10, rd_data);  // STATUS
        check(rd_data, 32'd0, "ADD overflow=0");

        // --------------------------------------------------
        // Test 2: SUB  (100 - 44 = 56)
        // --------------------------------------------------
        $display("\n[TEST 2] SUB: 100 - 44 = 56");
        axi_write(5'h00, 32'd100);
        axi_write(5'h04, 32'd44);
        axi_write(5'h08, 32'd1);    // OP_SEL = SUB
        axi_read (5'h0C, rd_data);
        check(rd_data, 32'd56, "SUB result");

        // --------------------------------------------------
        // Test 3: AND  (0xF0F0F0F0 & 0x0F0F0F0F = 0x00000000)
        // --------------------------------------------------
        $display("\n[TEST 3] AND: 0xF0F0F0F0 & 0x0F0F0F0F = 0x00000000");
        axi_write(5'h00, 32'hF0F0F0F0);
        axi_write(5'h04, 32'h0F0F0F0F);
        axi_write(5'h08, 32'd2);    // OP_SEL = AND
        axi_read (5'h0C, rd_data);
        check(rd_data, 32'h00000000, "AND result");

        // --------------------------------------------------
        // Test 4: OR   (0xF0F0F0F0 | 0x0F0F0F0F = 0xFFFFFFFF)
        // --------------------------------------------------
        $display("\n[TEST 4] OR: 0xF0F0F0F0 | 0x0F0F0F0F = 0xFFFFFFFF");
        axi_write(5'h08, 32'd3);    // OP_SEL = OR (operands unchanged)
        axi_read (5'h0C, rd_data);
        check(rd_data, 32'hFFFFFFFF, "OR result");

        // --------------------------------------------------
        // Test 5: ADD overflow detection
        // --------------------------------------------------
        $display("\n[TEST 5] ADD overflow: 0xFFFFFFFF + 1");
        axi_write(5'h00, 32'hFFFFFFFF);
        axi_write(5'h04, 32'd1);
        axi_write(5'h08, 32'd0);    // OP_SEL = ADD
        axi_read (5'h0C, rd_data);
        check(rd_data, 32'd0,       "overflow result=0");
        axi_read (5'h10, rd_data);
        check(rd_data, 32'd1,       "overflow status=1");

        // --------------------------------------------------
        // Summary
        // --------------------------------------------------
        $display("\n--------------------------------------------");
        $display(" RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" SOME TESTS FAILED - check waveforms");
        $display("--------------------------------------------");

        $finish;
    end

    // Safety timeout (prevents infinite loop if handshake breaks)
    initial begin
        #100000;
        $display("TIMEOUT - simulation exceeded 100us");
        $finish;
    end

endmodule