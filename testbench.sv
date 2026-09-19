`timescale 1ns/1ps
module tb_risc;
  reg clk;
  reg rst;
  
  RISC DUT (
    .clk(clk),
    .rst(rst)
  );

  integer cycle;
  integer i;
  integer nop_count;
  string instr_name;
  string b_src_str;
  string op_str;
  string mem_type_str;
  string rd_name;

  int a_dec, b_dec, res_dec;
  logic [31:0] mem_data_sel;

  // instruction encoding for No Operation 
  localparam NOP    = 32'h00000013; // addi x0,x0,0
  
 
  // clock generator: 10 ns period (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Reset
  initial begin
    rst = 1'b0; #10;
    rst = 1'b1;
  end
  
  // counters
  initial begin
    cycle = 0;
    nop_count = 0;
  end
  
  // increment cycle counter
  always @(posedge clk) cycle = cycle + 1;

  //Instruction Memory
  initial begin
  // R-type ALU ops (register-register)
  DUT.IM.instr_mem[0]  = 32'h00208533; // add   x10, x1, x2
  DUT.IM.instr_mem[1]  = 32'h401105b3; // sub   x11, x2, x1
  DUT.IM.instr_mem[2]  = 32'h0041f633; // and   x12, x3, x4
  DUT.IM.instr_mem[3]  = 32'h0041e6b3; // or    x13, x3, x4
  DUT.IM.instr_mem[4]  = 32'h0041c733; // xor   x14, x3, x4
  DUT.IM.instr_mem[5]  = 32'h006097b3; // sll   x15, x1, x6
  DUT.IM.instr_mem[6]  = 32'h00625833; // srl   x16, x4, x6
  DUT.IM.instr_mem[7]  = 32'h4062d8b3; // sra   x17, x5, x6
  DUT.IM.instr_mem[8]  = 32'h0020a933; // slt   x18, x1, x2
  DUT.IM.instr_mem[9]  = 32'h0020b9b3; // sltu  x19, x1, x2

  // I-type ALU ops (register-immediate)
  DUT.IM.instr_mem[10] = 32'h00508a13; // addi  x20, x1, 5
  DUT.IM.instr_mem[11] = 32'h00f1fa93; // andi  x21, x3, 0x0F
  DUT.IM.instr_mem[12] = 32'h0f01eb13; // ori   x22, x3, 0xF0
  DUT.IM.instr_mem[13] = 32'h0ff24b93; // xori  x23, x4, 0xFF

  // Memory ops
  DUT.IM.instr_mem[14] = 32'h0061a023; // sw    x6, 0(x3)
  DUT.IM.instr_mem[15] = 32'h0071a223; // sw    x7, 4(x3)
  DUT.IM.instr_mem[16] = 32'h0001ac03; // lw    x24, 0(x3)
  DUT.IM.instr_mem[17] = 32'h0041ac83; // lw    x25, 4(x3)

  // Fill rest with NOPs
    for (i = 18; i < 256; i = i + 1)
      DUT.IM.instr_mem[i] = NOP;
  end
  
  //Register Memory
  initial begin
    DUT.RM.regs[0]  = 32'h00000000; // x0 = 0
    DUT.RM.regs[1]  = 32'd10;       // x1 = 10
    DUT.RM.regs[2]  = 32'd20;       // x2 = 20
    DUT.RM.regs[3]  = 32'd0;        // x3 = 0  (base addr for lw/sw)
    DUT.RM.regs[4]  = 32'h000000F0; // x4 = 0xF0
    DUT.RM.regs[5]  = 32'h00000004; // x5 = 0x8000_0000 (for SRA sign test)
    DUT.RM.regs[6]  = 32'd1;        // x6 = 1  (shift amount & store data)
    DUT.RM.regs[7]  = 32'd2;        // x7 = 2  (store data)  
  end
  
  // Data Memory
  initial begin
    DUT.DM.mem[0] = 32'h00000000;
    DUT.DM.mem[1] = 32'h00000000;
    DUT.DM.mem[2] = 32'h00000000;
    DUT.DM.mem[3] = 32'h00000000;

  for (i = 4; i < 256; i = i + 1)
    DUT.DM.mem[i] = 32'h00000000;
  end
    
  // Nop counts and execution Termination
  always @(posedge clk or negedge rst)
    begin
      if(!rst)
        nop_count <= 0;
      else begin
        if (DUT.ifid_instr == NOP) begin
          nop_count <= nop_count + 1;
        end
        else begin
          nop_count <= 0;
        end
      end
      
      if(nop_count == 7) begin
        $display("\n---------------------------------------------------------------------------------------------Execution Completed------------------------------------------------------------------------------------------------\n\n\n\n");
        $finish;
      end
    end
  
  //Waveform Generation
  initial begin
    $dumpfile("risc_tb.vcd");
    $dumpvars;
  end
  
  
  //Displaying Output
  initial begin
    $display("\n\n\n\n\n==============================================================================================================================================================================================================");
    $display("Cycle |            FETCH              |                        DECODE                       |                          EXECUTE                              |          MEMORY           |       WRITEBACK");
    $display("      |  PC        INSTR      NAME    | MemR MemW RegW AluSrc MemToReg ImmSel ALUOP B_Src   | A(hex)(dec)       op   B(hex)(dec)     =     Res(hex)(dec)    | Type     Addr     Data    | RegW  rd   wb_data");
    $display("==============================================================================================================================================================================================================");
end

  always @(posedge clk) begin
  if (rst) begin
    
    // ---------------- FETCH: decode instruction name ----------------
    case (DUT.id_opcode)
      7'b0110011: instr_name = "R";   // R-type ALU
      7'b0010011: instr_name = "I";   // I-type ALU immediate
      7'b0000011: instr_name = "LW";  // load
      7'b0100011: instr_name = "SW";  // store
      default:    instr_name = " ";   // NOP / undefined
    endcase
    
    // ---------------- DECODE: B source (REG or IMM) ----------------
    if (DUT.id_alusrc)
      b_src_str = "IMM";
    else
      b_src_str = "REG";

    // ---------------- EXECUTE: choose operator string from ALU control ----------------
    case (DUT.ex_aluctrl)
      4'b0010: op_str = "+";     // ADD
      4'b0110: op_str = "-";     // SUB
      4'b0000: op_str = "&";     // AND
      4'b0001: op_str = "|";     // OR
      4'b1100: op_str = "^";     // XOR
      4'b0011: op_str = "<<";    // SLL
      4'b0101: op_str = ">>";    // SRL
      4'b1001: op_str = ">>>";   // SRA
      4'b1010: op_str = "<";     // SLTU
      4'b0111: op_str = "<";     // SLT
      default: op_str = "?";
    endcase

    // Decimal versions of A, B, Result (for understanding)
    a_dec   = DUT.idex_read_data1;
    b_dec   = DUT.ex_alu_b;
    res_dec = DUT.ex_alu_result;

    // ---------------- MEMORY: type + data selection ----------------
    if (DUT.exmem_memread) begin
      mem_type_str = "R";
      mem_data_sel = DUT.mem_read_data;
    end
    else if (DUT.exmem_memwrite) begin
      mem_type_str = "W";
      mem_data_sel = DUT.exmem_write_data;
    end
    else begin
      mem_type_str = "-";
      mem_data_sel = 32'd0;
    end

    // ---------------- WRITEBACK: rd name ----------------
    if (DUT.wb_regwrite && (DUT.wb_rd_reg != 0))
      rd_name = $sformatf("x%0d", DUT.wb_rd_reg);
    else
      rd_name = "--";

    // ---------------- FINAL PRINT ROW ----------------
    $display("%4d  | %08h  %08h    %-4s    |   %1b    %1b    %1b     %1b      %1b      %3b   %2b    %-3s     | %08h->%4d   %2s    %08h->%4d  =     %08h ->%4d  |   %s    %08h %08h  |  %1b    %s   %08h",
             cycle,
             DUT.pc,                 // FETCH: PC
             DUT.ifid_instr,         // FETCH: INSTR
             instr_name,             // FETCH: NAME
             DUT.idex_memread,         // DECODE: MemR
             DUT.idex_memwrite,        // DECODE: MemW
             DUT.idex_regwrite,        // DECODE: RegW
             DUT.idex_alusrc,          // DECODE: AluSrc
             DUT.idex_memtoreg,        // DECODE: MemToReg
             DUT.id_imm_sel,           // DECODE: ImmSel
             DUT.idex_aluop,          // DECODE: AluOp
             b_src_str,              // DECODE: B_src (REG/IMM)
             DUT.idex_read_data1,    // EXECUTE: A hex
             a_dec,                  // EXECUTE: A dec
             op_str,                 // EXECUTE: operator
             DUT.ex_alu_b,           // EXECUTE: B hex
             b_dec,                  // EXECUTE: B dec
             DUT.ex_alu_result,      // EXECUTE: Result hex
             res_dec,                // EXECUTE: Result dec
             mem_type_str,           // MEMORY: type
             DUT.exmem_alu_result,   // MEMORY: addr
             mem_data_sel,           // MEMORY: data
             DUT.wb_regwrite,        // WB: RegW
             rd_name,                // WB: rd as xN / --
             DUT.wb_write_data_reg   // WB: wb_data
             );
  end
end

endmodule
