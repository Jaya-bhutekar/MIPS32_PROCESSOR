`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Simple 5-stage pipelined MIPS-like processor (keeps your clk1/clk2 scheme)
// Cleaned and corrected version of your posted code.
//////////////////////////////////////////////////////////////////////////////////
module pipe_MIPS32(
    input clk1,
    input clk2
);

// ---------------------- Program / pipeline registers ------------------------
reg [31:0] PC;
reg [31:0] IF_ID_IR, IF_ID_NPC;

reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;
reg [2:0]  ID_EX_Type;

reg [31:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B;
reg        EX_MEM_cond;
reg [2:0]  EX_MEM_Type;

reg [31:0] MEM_WB_IR, MEM_WB_ALUOut, MEM_WB_LMD;
reg [2:0]  MEM_WB_Type;

reg        HALTED;
reg        TAKEN_BRANCH;

// Register file and memory
reg [31:0] RegFile [0:31];
reg [31:0] Mem [0:1023];

// --------------------------- Opcodes & types --------------------------------
parameter  OP_ADD   = 6'b000000;
parameter  OP_SUB   = 6'b000001;
parameter  OP_AND   = 6'b000010;
parameter  OP_OR    = 6'b000011;
parameter  OP_SLT   = 6'b000100;
parameter  OP_MUL   = 6'b000101;
parameter  OP_HALT  = 6'b111111;
parameter  OP_LW    = 6'b001000;
parameter  OP_SW    = 6'b001001;
parameter  OP_ADDI  = 6'b001010;
parameter  OP_SUBI  = 6'b001011;
parameter  OP_SLTI  = 6'b001100;
parameter  OP_BNEQZ = 6'b001101;
parameter  OP_BEQZ  = 6'b001110;

// pipeline "types"
parameter  T_RR_ALU = 3'b000;
parameter  T_RM_ALU = 3'b001;
parameter  T_LOAD   = 3'b010;
parameter  T_STORE  = 3'b011;
parameter  T_BRANCH = 3'b100;
parameter  T_HALT   = 3'b101;

// --------------------------- Instruction Fetch (IF) -------------------------
always @(posedge clk1) begin
    if (!HALTED) begin
        // Branch resolution uses EX/MEM stage outcome
        if (((EX_MEM_IR[31:26] == OP_BEQZ) && (EX_MEM_cond == 1'b1)) ||
            ((EX_MEM_IR[31:26] == OP_BNEQZ) && (EX_MEM_cond == 1'b0))) begin
            IF_ID_IR     <= #2 Mem[EX_MEM_ALUOut];
            //TAKEN_BRANCH <= #2 1'b1;
            IF_ID_NPC    <= #2 EX_MEM_ALUOut + 1;
            PC           <= #2 EX_MEM_ALUOut + 1;
        end
        else begin
            IF_ID_IR     <= #2 Mem[PC];
            IF_ID_NPC    <= #2 PC + 1;
            PC           <= #2 PC + 1;
            //TAKEN_BRANCH <= #2 1'b0;
        end
    end
end

// --------------------------- Instruction Decode (ID) ------------------------
always @(posedge clk2) begin
    if (!HALTED) begin
        // Read operands (with x0 == 0)
        if (IF_ID_IR[25:21] == 5'b00000) ID_EX_A <= #2 32'b0;
        else                              ID_EX_A <= #2 RegFile[IF_ID_IR[25:21]];

        if (IF_ID_IR[20:16] == 5'b00000) ID_EX_B <= #2 32'b0;
        else                              ID_EX_B <= #2 RegFile[IF_ID_IR[20:16]];

        ID_EX_NPC  <= #2 IF_ID_NPC;
        ID_EX_IR   <= #2 IF_ID_IR;
        ID_EX_Imm  <= #2 {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]}; // sign-extend

        // Classify instruction type
        case (IF_ID_IR[31:26])
            OP_ADD, OP_SUB, OP_AND, OP_OR, OP_SLT, OP_MUL:
                ID_EX_Type <= #2 T_RR_ALU;
            OP_ADDI, OP_SUBI, OP_SLTI:
                ID_EX_Type <= #2 T_RM_ALU;
            OP_LW:
                ID_EX_Type <= #2 T_LOAD;
            OP_SW:
                ID_EX_Type <= #2 T_STORE;
            OP_BNEQZ, OP_BEQZ:
                ID_EX_Type <= #2 T_BRANCH;
            OP_HALT:
                ID_EX_Type <= #2 T_HALT;
            default:
                ID_EX_Type <= #2 T_HALT;
        endcase
    end
end

// --------------------------- Execute (EX) ----------------------------------
always @(posedge clk1) begin
    if (!HALTED) begin
        EX_MEM_Type <= #2 ID_EX_Type;
        EX_MEM_IR   <= #2 ID_EX_IR;
        TAKEN_BRANCH <= #2 1'b0; // default

        case (ID_EX_Type)
            T_RR_ALU: begin
                case (ID_EX_IR[31:26])
                    OP_ADD: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_B;
                    OP_SUB: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_B;
                    OP_AND: EX_MEM_ALUOut <= #2 (ID_EX_A & ID_EX_B);
                    OP_OR:  EX_MEM_ALUOut <= #2 (ID_EX_A | ID_EX_B);
                    OP_SLT: EX_MEM_ALUOut <= #2 ($signed(ID_EX_A) < $signed(ID_EX_B));
                    OP_MUL: EX_MEM_ALUOut <= #2 ID_EX_A * ID_EX_B;
                    default: EX_MEM_ALUOut <= #2 32'hXXXXXXXX;
                endcase
            end

            T_RM_ALU: begin
                case (ID_EX_IR[31:26])
                    OP_ADDI: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;
                    OP_SUBI: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_Imm;
                    OP_SLTI: EX_MEM_ALUOut <= #2 ($signed(ID_EX_A) < $signed(ID_EX_Imm));
                    default: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm; // what happening here
                endcase
            end

            T_LOAD, T_STORE: begin
                EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm; // effective address
                EX_MEM_B      <= #2 ID_EX_B;             // value to store for SW
            end

            T_BRANCH: begin
                EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_Imm; // branch target PC
                EX_MEM_cond   <= #2 (ID_EX_A == 0);        // condition: A == 0
            end// what ?

            T_HALT: begin
                // nothing computed; will be handled in WB stage
                EX_MEM_ALUOut <= #2 32'b0;
            end

            default: begin
                EX_MEM_ALUOut <= #2 32'hXXXXXXXX;
            end
        endcase
    end
end

// --------------------------- Memory (MEM) ----------------------------------
always @(posedge clk2) begin
    if (!HALTED) begin
        MEM_WB_Type  <= #2 EX_MEM_Type;
        MEM_WB_IR    <= #2 EX_MEM_IR;

        case (EX_MEM_Type)
            T_RR_ALU, T_RM_ALU:
                MEM_WB_ALUOut <= #2 EX_MEM_ALUOut;

            T_LOAD:
                MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut]; // load from memory

            T_STORE: begin
                if (TAKEN_BRANCH == 1'b0)
                    Mem[EX_MEM_ALUOut] <= #2 EX_MEM_B; // store to memory
            end

            default: begin
                // nothing
            end
        endcase
    end
end

// --------------------------- Write Back (WB) --------------------------------
always @(posedge clk1) begin
    if (!TAKEN_BRANCH) begin
        case (MEM_WB_Type)
            T_RR_ALU:
                RegFile[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUOut; // rd
            T_RM_ALU:
                RegFile[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOut; // rt
            T_LOAD:
                RegFile[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD;    // rt
            T_HALT:
                HALTED <= #2 1'b1;
            default: begin
                // do nothing
            end
        endcase
    end
end

endmodule
