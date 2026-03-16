// axi4_lite_slave.v
// AXI4-Lite slave wrapper around ALU core
//
// Register map (word-addressed, 32-bit wide):
//   0x00  OPERAND_A  R/W
//   0x04  OPERAND_B  R/W
//   0x08  OP_SEL     R/W  [1:0]
//   0x0C  RESULT     RO
//   0x10  STATUS     RO   [0]=overflow

module axi4_lite_slave #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5          // 5 bits covers 0x00-0x1C
)(
    // Global
    input  wire                    aclk,
    input  wire                    aresetn,         // active-low reset

    // Write Address channel (AW)
    input  wire [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire                    s_axi_awvalid,
    output reg                     s_axi_awready,

    // Write Data channel (W)
    input  wire [DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                    s_axi_wvalid,
    output reg                     s_axi_wready,

    // Write Response channel (B)
    output reg  [1:0]              s_axi_bresp,
    output reg                     s_axi_bvalid,
    input  wire                    s_axi_bready,

    // Read Address channel (AR)
    input  wire [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire                    s_axi_arvalid,
    output reg                     s_axi_arready,

    // Read Data channel (R)
    output reg  [DATA_WIDTH-1:0]   s_axi_rdata,
    output reg  [1:0]              s_axi_rresp,
    output reg                     s_axi_rvalid,
    input  wire                    s_axi_rready
);

    // -------------------------------------------------------
    // Internal registers
    // -------------------------------------------------------
    reg [31:0] reg_operand_a;
    reg [31:0] reg_operand_b;
    reg [1:0]  reg_op_sel;

    // ALU outputs (wires, combinational)
    wire [31:0] alu_result;
    wire        alu_overflow;

    // Latch write address internally
    reg [ADDR_WIDTH-1:0] awaddr_lat;
    reg                  aw_active;   // address has been accepted, waiting for data

    // -------------------------------------------------------
    // ALU instantiation
    // -------------------------------------------------------
    alu_core u_alu (
        .operand_a (reg_operand_a),
        .operand_b (reg_operand_b),
        .op_sel    (reg_op_sel),
        .result    (alu_result),
        .overflow  (alu_overflow)
    );

    // -------------------------------------------------------
    // WRITE path - AW + W channels
    // -------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            aw_active     <= 1'b0;
            reg_operand_a <= 32'd0;
            reg_operand_b <= 32'd0;
            reg_op_sel    <= 2'd0;
        end else begin

            // --- Accept write address ---
            if (s_axi_awvalid && s_axi_awready) begin
                awaddr_lat    <= s_axi_awaddr;
                aw_active     <= 1'b1;
                s_axi_awready <= 1'b0;
            end else if (!aw_active && !s_axi_awready) begin
                s_axi_awready <= 1'b1;   // ready to accept new address
            end

            // --- Accept write data and perform write ---
            if (s_axi_wvalid && s_axi_wready) begin
                s_axi_wready <= 1'b0;
                aw_active    <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;  // OKAY

                // Byte-enable aware write
                case (awaddr_lat[4:2])
                    3'd0: begin  // 0x00 OPERAND_A
                        if (s_axi_wstrb[0]) reg_operand_a[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_operand_a[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_operand_a[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_operand_a[31:24] <= s_axi_wdata[31:24];
                    end
                    3'd1: begin  // 0x04 OPERAND_B
                        if (s_axi_wstrb[0]) reg_operand_b[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_operand_b[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_operand_b[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_operand_b[31:24] <= s_axi_wdata[31:24];
                    end
                    3'd2: begin  // 0x08 OP_SEL
                        if (s_axi_wstrb[0]) reg_op_sel <= s_axi_wdata[1:0];
                    end
                    default: ; // 0x0C, 0x10 are read-only - silently ignore writes
                endcase

            end else if (aw_active && !s_axi_wready) begin
                s_axi_wready <= 1'b1;   // address latched, now accept data
            end

            // --- Clear bvalid once master acknowledges ---
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // -------------------------------------------------------
    // READ path - AR + R channels
    // -------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
            s_axi_rresp   <= 2'b00;
        end else begin

            if (s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;  // OKAY

                case (s_axi_araddr[4:2])
                    3'd0: s_axi_rdata <= reg_operand_a;
                    3'd1: s_axi_rdata <= reg_operand_b;
                    3'd2: s_axi_rdata <= {30'd0, reg_op_sel};
                    3'd3: s_axi_rdata <= alu_result;          // RESULT (live from ALU)
                    3'd4: s_axi_rdata <= {31'd0, alu_overflow}; // STATUS
                    default: s_axi_rdata <= 32'hDEAD_BEEF;   // undefined address
                endcase
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;
        end
    end

endmodule