//-------(Program Counter)-----//
module pc(
  input wire clk,
  input wire rst,
  output reg [31:0]pc_out
);
  always @(posedge clk or negedge rst) begin
      if(!rst)
        pc_out <= 32'd0;
      else
        pc_out <= pc_out + 32'd4;
  end
endmodule


//-----------(instruction Memory)------------//
module instr_mem(
  input wire [31:0]read_addr,
  output reg [31:0]instr
);
  reg [31:0]instr_mem[0:255];
  always @(*) begin
    instr = instr_mem[read_addr[9:2]];
  end
endmodule


//------(Control Signals)----//
module ctrl_sig(
  input wire [6:0]opcode,
  output reg memread,
  output reg memwrite,
  output reg memtoreg,
  output reg regwrite,
  output reg alusrc,
  output reg [1:0]aluop,
  output reg [2:0]imm_sel
);
  
  always @(*) begin
      //--Initialized the signals---//
      memread  = 1'b0;
      memwrite = 1'b0;
      memtoreg  = 1'b0;
      regwrite = 1'b0;
      alusrc   = 1'b0;
      aluop    = 2'b00;
      imm_sel  = 3'b000;
      
      case(opcode)
        7'b0110011: begin //Register Type (R)
          regwrite = 1'b1;
          aluop = 2'b10;
        end
        
        7'b0010011: begin //Immediate Type (I)
          regwrite = 1'b1;
          alusrc = 1'b1;
          aluop = 2'b10;
        end
        
        7'b0000011: begin //Load Word Type (LW)
          regwrite = 1'b1;
          memread = 1'b1;
          memtoreg = 1'b1;
          alusrc = 1'b1;
        end
        
        7'b0100011: begin //Store Word Type (SW)
          memwrite = 1'b1;
          alusrc = 1'b1;
          imm_sel = 3'b001;
        end
        
        default: begin
          memread  = 1'b0;
          memwrite = 1'b0;
          memtoreg  = 1'b0;
          regwrite = 1'b0;
          alusrc   = 1'b0;
          aluop    = 2'b00;
          imm_sel  = 3'b000;
        end
      endcase
  end
endmodule


//-------(Register Memory)------//
module reg_mem(
  input wire clk,
  input wire regwrite,
  input wire [31:0]writedata,
  input wire [4:0]rs1,
  input wire [4:0]rs2,
  input wire [4:0]rd,
  output wire [31:0]read_data1,
  output wire [31:0]read_data2
);
  reg [31:0] regs [0:31]; // 32 Registers each of 32 bit 
  
  //Initialized All Register Values to zero
  integer i;
  initial begin
    for(i=0;i<32;i=i+1)
      regs[i] = 32'd0;
  end
  
  assign read_data1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
  assign read_data2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];
  
  always @(posedge clk) begin
    if(regwrite && (rd != 5'd0)) begin 
      regs[rd] <= writedata;
    end
  end
endmodule


//------(Immediate Generator)-----//
module imm_gen(
  input wire [31:0]instr,
  input wire [2:0]imm_sel,
  output reg [31:0]imm_out
);
  always @(*) begin
      case(imm_sel)
        3'b000: imm_out = {{20{instr[31]}},instr[31:20]}; //At present used for all type of instruction leaving s-Type 
        
        3'b001: imm_out = {{20{instr[31]}},instr[31:25],instr[11:7]}; // For S-Type
        
        default: imm_out = 32'h0000_0000;
      endcase
  end
endmodule


//--------(ALU Control)------//
module alu_ctrl(
  input wire [1:0]aluop,
  input wire [2:0]funct3,
  input wire [6:0]funct7,
  output reg [3:0]aluctrl
);
  
  always @(*) begin
    case(aluop)
      2'b00: aluctrl = 4'b0010; // ADD for LW/SW
      
      2'b10: begin
        case(funct3)
          3'b000: aluctrl = (funct7 == 7'b0100000) ? 4'b0110 : 4'b0010; // SUB / ADD
          3'b001: aluctrl = 4'b0011; // SLL
          3'b010: aluctrl = 4'b0111; // SLT
          3'b011: aluctrl = 4'b1010; // SLTU
          3'b100: aluctrl = 4'b1100; // XOR
          3'b101: aluctrl = (funct7 == 7'b0100000) ? 4'b1001 : 4'b0101; // SRA / SRL
          3'b110: aluctrl = 4'b0001; // OR
          3'b111: aluctrl = 4'b0000; // AND
          default: aluctrl = 4'b0010; //ADD
        endcase
      end
      default: aluctrl = 4'b0010; // ADD
    endcase
  end
endmodule


//----------(ALU)--------//
module alu(
  input wire [31:0]a,
  input wire [31:0]b,
  input wire [3:0]aluctrl,
  output reg [31:0]res
);
  wire [4:0]shamt = b[4:0]; // shift amount needs lower 5 bits of 2nd operand
  
  always @(*) begin
    case(aluctrl)
      4'b0000: res = a & b;
      4'b0001: res = a | b;
      4'b0010: res = a + b;
      4'b0110: res = a - b;
      4'b1100: res = a ^ b;
      4'b0011: res = (a << shamt); // Shift Left Logical
      4'b0101: res = (a >> shamt); // Shift Right Logical
      4'b1001: res = ($signed(a) >>> shamt); // Shift Right Arithemetic
      4'b1010: res = (a < b) ? 32'd1 : 32'd0; // Set Less than (Unsigned Compare)
      4'b0111: res = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // Set Less Than (Signed Compare)
      default: res = 32'd0;
    endcase
  end
endmodule


//---------(Data Memory)------//
module data_mem(
  input wire clk,
  input wire memread,
  input wire memwrite,
  input wire [31:0]addr,
  input wire [31:0]writedata,
  output reg [31:0]readdata
);
  
  reg [31:0] mem [0:255]; // 256 words x 32 bits = 1024 bytes (1KB)
  
  always @(*) begin // used blocking statement Asynchronchrous read (combinational type)
    if(memread)
      readdata = mem[addr[9:2]];
    else 
      readdata = 32'd0;
  end
  
  always @(posedge clk) begin // used non-blocking Synchronous Write
    if(memwrite)
      mem[addr[9:2]] <= writedata;
  end
endmodule


//-------(op2 Mux)------//
module b_mux(
  input wire alusrc,
  input wire [31:0]s0, // Read_data2
  input wire [31:0]s1, // imm_out
  output wire [31:0]out
);
  assign out = (alusrc) ? s1 : s0;
endmodule


//--------(Register Write_data Mux)------//
module write_data_mux(
  input wire memtoreg,
  input wire [31:0]s0, // ALU Result
  input wire [31:0]s1, // read_data
  output wire [31:0]out
);
  assign out = (memtoreg) ? s1 : s0;
endmodule




//-----(Top Module)----//
module RISC (
  input wire clk,
  input wire rst
);

  // ---------- IF stage ----------
  
  wire [31:0] pc;
  pc PC (
    .clk(clk),
    .rst(rst),
    .pc_out(pc)
  );

  // Instruction memory 
  wire [31:0] instr_if;
  instr_mem IM (
    .read_addr(pc),
    .instr(instr_if)
  );

  // IF/ID pipeline register (internal regs)
  
  reg [31:0] ifid_pc;
  reg [31:0] ifid_instr;

  // ---------- ID stage signals ----------
  
  wire [6:0] id_opcode  = ifid_instr[6:0];
  wire [4:0] id_rs1     = ifid_instr[19:15];
  wire [4:0] id_rs2     = ifid_instr[24:20];
  wire [4:0] id_rd      = ifid_instr[11:7];
  wire [2:0] id_funct3  = ifid_instr[14:12];
  wire [6:0] id_funct7  = ifid_instr[31:25];

  // Control Signals 
  wire id_memread, id_memwrite, id_memtoreg, id_regwrite, id_alusrc;
  wire [1:0] id_aluop;
  wire [2:0] id_imm_sel;

  ctrl_sig CS (
    .opcode(id_opcode),
    .memread(id_memread),
    .memwrite(id_memwrite),
    .memtoreg(id_memtoreg),
    .regwrite(id_regwrite),
    .alusrc(id_alusrc),
    .aluop(id_aluop),
    .imm_sel(id_imm_sel)
  );

  // Register Memory read 
  wire [31:0] rf_read1, rf_read2;
  
  // WB stage connection wires (driven later)
  reg wb_regwrite;         // will be assigned from MEM/WB reg at posedge
  reg [4:0] wb_rd_reg;     // destination register index for writeback
  reg [31:0] wb_write_data_reg; // data to write back (from MEM/WB)
  
  //Register Memory 
  reg_mem RM (
    .clk(clk),
    .regwrite(wb_regwrite),
    .writedata(wb_write_data_reg),
    .rs1(id_rs1),
    .rs2(id_rs2),
    .rd(wb_rd_reg),
    .read_data1(rf_read1),
    .read_data2(rf_read2)
  );

  // Immediate Generator
  wire [31:0] imm_id;
  imm_gen IG (
    .instr(ifid_instr),
    .imm_sel(id_imm_sel),
    .imm_out(imm_id)
  );

  
  // ---------- ID/EX pipeline registers ----------//
  
  reg idex_regwrite;
  reg idex_memread;
  reg idex_memwrite;
  reg idex_memtoreg;
  reg idex_alusrc;
  reg [1:0] idex_aluop;

  reg [31:0] idex_read_data1;
  reg [31:0] idex_read_data2;
  reg [31:0] idex_imm;
  reg [4:0]  idex_rs1;
  reg [4:0]  idex_rs2;
  reg [4:0]  idex_rd;
  reg [2:0]  idex_funct3;
  reg [6:0]  idex_funct7;

  
  // ---------- EX stage ----------
  
  // ALU control 
  wire [3:0] ex_aluctrl;
  alu_ctrl ALUCTRL (
    .aluop(idex_aluop),
    .funct3(idex_funct3),
    .funct7(idex_funct7),
    .aluctrl(ex_aluctrl)
  );

  // ALU operand mux (B)
  wire [31:0] ex_alu_b;
  b_mux BM (
    .alusrc(idex_alusrc),
    .s0(idex_read_data2),
    .s1(idex_imm),
    .out(ex_alu_b)
  );

  // ALU (combinational)
  wire [31:0] ex_alu_result;
  alu ALU (
    .a(idex_read_data1),
    .b(ex_alu_b),
    .aluctrl(ex_aluctrl),
    .res(ex_alu_result)
  );

  
  // ---------- EX/MEM pipeline registers ----------
  
  reg exmem_regwrite;
  reg exmem_memread;
  reg exmem_memwrite;
  reg exmem_memtoreg;
  reg [31:0] exmem_alu_result;
  reg [31:0] exmem_write_data; // value from rs2 to be written to memory for SW
  reg [4:0]  exmem_rd;

  // ---------- MEM stage ----------
  
  // Data Memory 
  wire [31:0] mem_read_data;
  data_mem DM (
    .clk(clk),
    .memread(exmem_memread),
    .memwrite(exmem_memwrite),
    .addr(exmem_alu_result),
    .writedata(exmem_write_data),
    .readdata(mem_read_data)
  );

  
  // ---------- MEM/WB pipeline registers ----------
  
  reg memwb_regwrite;
  reg memwb_memtoreg;
  reg [31:0] memwb_memread_data;
  reg [31:0] memwb_alu_result;
  reg [4:0]  memwb_rd;

  // ---------- WB stage ----------
  // At posedge clk we will assign wb outputs to reg_mem write inputs
  wire [31:0] wb_selected;
  write_data_mux WDM (
    .memtoreg(memwb_memtoreg),
    .s0(memwb_alu_result),
    .s1(memwb_memread_data),
    .out(wb_selected)
  );

  
  //--------- Pipelined Stages Latch Logic  --------
  
  // ---------- IF/ID latch logic ----------
  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      ifid_pc    <= 32'd0;
      ifid_instr <= 32'd0;
    end else begin
      ifid_pc    <= pc;
      ifid_instr <= instr_if;
    end
  end

  // ---------- ID/EX latch logic ----------
  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      idex_regwrite   <= 1'b0;
      idex_memread    <= 1'b0;
      idex_memwrite   <= 1'b0;
      idex_memtoreg   <= 1'b0;
      idex_alusrc     <= 1'b0;
      idex_aluop      <= 2'b00;
      idex_read_data1 <= 32'd0;
      idex_read_data2 <= 32'd0;
      idex_imm        <= 32'd0;
      idex_rs1        <= 5'd0;
      idex_rs2        <= 5'd0;
      idex_rd         <= 5'd0;
      idex_funct3     <= 3'd0;
      idex_funct7     <= 7'd0;
    end else begin
      // Pass control signals
      idex_regwrite   <= id_regwrite;
      idex_memread    <= id_memread;
      idex_memwrite   <= id_memwrite;
      idex_memtoreg   <= id_memtoreg;
      idex_alusrc     <= id_alusrc;
      idex_aluop      <= id_aluop;
      // Pass data
      idex_read_data1 <= rf_read1;
      idex_read_data2 <= rf_read2;
      idex_imm        <= imm_id;
      idex_rs1        <= id_rs1;
      idex_rs2        <= id_rs2;
      idex_rd         <= id_rd;
      idex_funct3     <= id_funct3;
      idex_funct7     <= id_funct7;
    end
  end

  // ---------- EX/MEM latch logic ----------
  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      exmem_regwrite   <= 1'b0;
      exmem_memread    <= 1'b0;
      exmem_memwrite   <= 1'b0;
      exmem_memtoreg   <= 1'b0;
      exmem_alu_result <= 32'd0;
      exmem_write_data <= 32'd0;
      exmem_rd         <= 5'd0;
    end else begin
      exmem_regwrite   <= idex_regwrite;
      exmem_memread    <= idex_memread;
      exmem_memwrite   <= idex_memwrite;
      exmem_memtoreg   <= idex_memtoreg;
      exmem_alu_result <= ex_alu_result;
      exmem_write_data <= idex_read_data2;
      exmem_rd         <= idex_rd;
    end
  end

  // ---------- MEM/WB latch logic ----------
  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      memwb_regwrite      <= 1'b0;
      memwb_memtoreg      <= 1'b0;
      memwb_memread_data  <= 32'd0;
      memwb_alu_result    <= 32'd0;
      memwb_rd            <= 5'd0;
    end else begin
      memwb_regwrite      <= exmem_regwrite;
      memwb_memtoreg      <= exmem_memtoreg;
      memwb_memread_data  <= mem_read_data;
      memwb_alu_result    <= exmem_alu_result;
      memwb_rd            <= exmem_rd;
    end
  end


  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      wb_regwrite      <= 1'b0;
      wb_rd_reg        <= 5'd0;
      wb_write_data_reg<= 32'd0;
    end else begin
      wb_regwrite       <= memwb_regwrite;
      wb_rd_reg         <= memwb_rd;
      wb_write_data_reg <= wb_selected;
    end
  end

endmodule
