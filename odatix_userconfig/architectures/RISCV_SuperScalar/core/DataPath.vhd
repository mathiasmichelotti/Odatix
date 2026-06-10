-------------------------------------------------------------------------
-- Design unit: Data path
-- Description: 
-------------------------------------------------------------------------
--██████████████████████████████████████████████████████████████████████████████████
--██                                                                              ██
--██ ██████═╗  █████╗ ████████╗ █████╗        ████████╗ █████╗ ████████╗██╗   ██╗ ██
--██ ██╔══██╚╗██╔══██╗╚══██╔══╝██╔══██╗       ██╔═══██║██╔══██╗╚══██╔══╝██║   ██║ ██
--██ ██║   ██║███████║   ██║   ███████║       ████████║███████║   ██║   ████████║ ██
--██ ██║  ██╔╝██╔══██║   ██║   ██╔══██║       ██╔═════╝██╔══██║   ██║   ██╔═══██║ ██
--██ ██████╔╝ ██║  ██║   ██║   ██║  ██║       ██║      ██║  ██║   ██║   ██║   ██║ ██
--██ ╚═════╝  ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝       ╚═╝      ╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝ ██
--██████████████████████████████████████████████████████████████████████████████████

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all; 
use work.RISCV_package.all;

   
entity DataPath is
    generic (
        PC_START_ADDRESS    : integer := 0;
        SYNTHESIS           : boolean := false;
        DATA_WIDTH          : integer := 32;
        INST_WIDTH          : integer := 64;
        ISSUE_WIDTH         : natural := 2
    );
    port (  
        clock               : in  std_logic;
        reset               : in  std_logic;
        instructionAddress  : out std_logic_vector(DATA_WIDTH-1 downto 0);  -- Instruction memory address bus
        instruction_in      : in  std_logic_vector(INST_WIDTH-1 downto 0);  -- Data bus from instruction memory
        dataAddress         : out Data_array;  -- Data memory address bus
        data_i              : in  Data_array;  -- Data bus from data memory 
        data_o              : out Data_array;  -- Data bus to data memory
        MemWrite            : out MemWrite_array; 
        instruction_out     : out Data_array;                                -- Data bus from instruction of Stage_ID for Decode by Control Path
        uins_ID             : in  Microinstruction_array                    -- Control path microinstruction
    );
end DataPath;


architecture structural of DataPath is

    -- Instruction Fetch Stage Signals:
    signal incrementedPC_IF, pc_d, pc_q : std_logic_vector(31 downto 0);
    signal ce_pc, ce_pc_dep, ce_pc_hazard : std_logic;
    signal instruction_IF, PC_IF, btb_predict_target_IF : Data_array; --> (0 to 1) of std_logic_vector(31 downto 0)
    signal btb_predict_taken_IF : std_logic_vector(1 downto 0);

    -- Instruction Decode Stage Signals:
    signal instruction_ID : Data_array; --> (0 to 1) of std_logic_vector(31 downto 0)
    signal PC_ID, readData1_ID, readData2_ID, imm_data_ID, jumpTarget : Data_array; --> (0 to 1) of std_logic_vector(31 downto 0)
    signal branchTarget, Data1_ID, Data2_ID : Data_array; --> (0 to 1) of std_logic_vector(31 downto 0)
    signal rs1_ID, rs2_ID, rd_ID : Reg_array; --> (0 to 1) of std_logic_vector(4 downto 0);
    signal ce_stage_ID, bubble_dep_inst0_ID, bubble_branch, branch_decision, btb_predict_taken_ID : std_logic_vector(1 downto 0); --> (0 to 1) of std_logic; 
    signal ce_stage_ID_dep, ce_stage_ID_hazard : std_logic;
    signal valid_ID : Boolean_vector(1 downto 0); --> (0 to 1) of boolean;

    -- Execution Stage Signals:
    signal result_EX, readData1_EX, readData2_EX, operand1, operand2 : Data_array; --> (0 to 1) of std_logic_vector(31 downto 0)
    signal ALUoperand2, imm_data_EX, PC_EX : Data_array; --> (0 to 1) of std_logic_vector(31 downto 0)
    signal uins_EX : Microinstruction_array; --> (0 to 1) of Microinstruction;
    signal rd_EX, rs2_EX, rs1_EX : Reg_array; --> (0 to 1) of std_logic_vector(4 downto 0);
    signal bubble_dep_inst1_EX, bubble_branch_inst1_MEM, btb_predict_taken_EX : std_logic_vector(1 downto 0); --> (0 to 1) of std_logic; 
    signal bubble_hazard_EX : std_logic;
    signal valid_EX : Boolean_vector(1 downto 0); --> (0 to 1) of boolean;

    -- Memory Stage Signals:
    signal result_MEM : Data_array; --> (0 to 1) of std_logic_vector(31 downto 0)
    signal uins_MEM : Microinstruction_array; --> (0 to 1) of Microinstruction;
    signal CSR_MEM : CSR_array; --> (0 to 1) of std_logic_vector(7 downto 0)
    signal rd_MEM : Reg_array; --> (0 to 1) of std_logic_vector(4 downto 0);
    signal valid_MEM : Boolean_vector(1 downto 0); --> (0 to 1) of boolean;

    -- Write Back Stage Signals:
    signal writeData, data_i_WB, result_WB, CSR_DATA_WB: Data_array; --> (0 to 1) of std_logic_vector(31 downto 0)
    signal uins_WB : Microinstruction_array; --> (0 to 1) of Microinstruction;
    signal CSR_WB : CSR_array; --> (0 to 1) of std_logic_vector(7 downto 0)
    signal rd_WB : Reg_array; --> (0 to 1) of std_logic_vector(4 downto 0);

    -- Auxiliar Signals:
    signal ForwardA, ForwardB : Select_array_3b; --> (0 to 1) of std_logic_vector(2 downto 0);
    signal ForwardWb_A, ForwardWb_B : Select_array_2b; -->  (0 to 1) of std_logic_vector(1 downto 0); 

    -- SIMULATION Signals:
    type Instruction_type_array is array (0 to 1) of Instruction_type;
    type Instruction_format_array is array (0 to 1) of Instruction_format;
    type op_func7_array is array (0 to 1) of std_logic_vector(6 downto 0);
    type func3_array is array (0 to 1) of std_logic_vector(2 downto 0);

    signal decodedInstruction_IF: Instruction_type_array;
    signal decodedFormat_IF:      Instruction_format_array;
    signal opcode: op_func7_array;
    signal funct3: func3_array;
    signal funct7: op_func7_array; 

begin

    instruction_IF(0) <= instruction_in(31 downto 0);
    instruction_IF(1) <= instruction_in(63 downto 32);

    -- Instruction_out receive instruction_out of Stage 1 for decodification by Control Path
    instruction_out <= instruction_ID;

    -- incrementedPC_IF points the next instruction address
    -- ADDER over the PC register
    ADDER_PC: incrementedPC_IF <= STD_LOGIC_VECTOR(UNSIGNED(pc_q) + TO_UNSIGNED(8,32));
        
    -- Instruction memory is addressed by the PC register
    instructionAddress <= pc_q;
    
    PC_IF(0) <= pc_q; -- actual pc ins[0]
    PC_IF(1) <= STD_LOGIC_VECTOR(UNSIGNED(pc_q) + TO_UNSIGNED(4,32)); -- actual pc ins[1]
    
    -- MUX which selects the PC value
    MUX_PC: pc_d <= branchTarget(0)                                           when (btb_predict_taken_EX(0) = '0' and bubble_branch(0) = '1') else -- prevision not taken, but was taken
                    jumpTarget(0)                                             when uins_EX(0).instruction = JALR else
                    branchTarget(1)                                           when (btb_predict_taken_EX(1) = '0' and bubble_branch(1) = '1' and branch_decision(0) = '0') else -- prevision not taken, but was taken, verify branch_decision(0) because if '1' the (BRANCH, JUMP) in the slot 2 is invalid / prioritize the branch in slot 0 because we always execute the instruction in slot 1, so if the branch in slot 0 is not taken, the instruction in slot 1 is correct and if is branch need to change the PC to jumpTarget(1) not PC+8
                    jumpTarget(1)                                             when uins_EX(1).instruction = JALR and branch_decision(0) = '0' else -- the same priority for jalr
                    STD_LOGIC_VECTOR(UNSIGNED(PC_EX(0)) + TO_UNSIGNED(8,32))  when (btb_predict_taken_EX(0) = '1' and bubble_branch(0) = '1') else -- prevision taken, but was not taken (PC_ID + 8 because we always execute the instrcution PC_ID + 4 in the slot 2)
                    STD_LOGIC_VECTOR(UNSIGNED(PC_EX(1)) + TO_UNSIGNED(4,32))  when (btb_predict_taken_EX(1) = '1' and bubble_branch(1) = '1' and branch_decision(0) = '0') else -- prevision taken, but was not taken
                    btb_predict_target_IF(0)                                  when btb_predict_taken_IF(0) = '1' else
                    btb_predict_target_IF(1)                                  when btb_predict_taken_IF(1) = '1' else
                    incrementedPC_IF;

    -----------------------------------------------------------------------------------------------------------------------
    
    -- PC register
    PROGRAM_COUNTER:    entity work.RegisterNbits
        generic map (
            LENGTH      => 32,
            INIT_VALUE  => PC_START_ADDRESS
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => ce_pc, 
            d           => pc_d, 
            q           => pc_q
        );
    
    -- Branch Predictor
    BRANCH_PREDICTOR: entity work.BTB_superscalar
        generic map(
            BTB_BITS => 4 -- 2^4 = 16 linhas
        )
        port map(
            clock         => clock,
            reset         => reset,
            pc_in         => PC_IF,
            predict_taken => btb_predict_taken_IF,
            predict_pc    => btb_predict_target_IF,
            inst_format_0 => uins_EX(0).format,
            inst_format_1 => uins_EX(1).format,
            pc_update     => PC_EX,
            target_real   => branchTarget,
            taken_real    => branch_decision
        );

    -- Register file
    REGISTER_FILE: entity work.RegisterFile(structural)
        port map (
            clock             => clock,
            reset             => reset,            
            write_a           => uins_WB(0).RegWrite,   
            write_b           => uins_WB(1).RegWrite, 
            rs1_a             => rs1_ID(0),    
            rs2_a             => rs2_ID(0),
            rs1_b             => rs1_ID(1), 
            rs2_b             => rs2_ID(1), 
            writeRegister_a   => rd_WB(0),
            writeRegister_b   => rd_WB(1), 
            writeData_a       => writeData(0), 
            writeData_b       => writeData(1),
            readData1_a       => readData1_ID(0),        
            readData2_a       => readData2_ID(0),
            readData1_b       => readData1_ID(1),  
            readData2_b       => readData2_ID(1)
        );

    
    DEPENDENCY_INSTRUCTIONS_ID: entity work.Double_issue_dep(arch1)
        port map (
            rs1_inst1           => rs1_ID(1),
            rs2_inst1           => rs2_ID(1),
            rd_inst0            => rd_ID(0),          
            ce_pc               => ce_pc_dep,  -- stall pc dependency bewteen inst[0] and inst[1] in ID
            ce_stage_ID         => ce_stage_ID_dep, -- stall ID registers
            bubble_dep_inst1_EX => bubble_dep_inst1_EX(1), 
            bubble_dep_inst0_ID => bubble_dep_inst0_ID(0)  
        );

    ce_stage_ID(0) <= ce_stage_ID_hazard or bubble_branch(0) or bubble_branch(1); -- do not receive ce_stage_ID_dep because recive bubble (bubble_mux)
    ce_stage_ID(1) <= (ce_stage_ID_dep and ce_stage_ID_hazard) or bubble_branch(0) or bubble_branch(1); 
     
    ce_pc <= (ce_pc_dep and ce_pc_hazard) or bubble_branch(0) or bubble_branch(1); -- stall pc when isn't bubble in ID/EX and hazard detected

    bubble_dep_inst1_EX(0) <= '0'; -- bubble only in inst1, signal necessary for gen_duplicate 
    bubble_dep_inst0_ID(1) <= '0'; -- bubble only in inst0, signal necessary for gen_duplicate 

    bubble_branch_inst1_MEM(0) <= '0'; -- bubble only in inst1, signal necessary for gen_duplicate  
    bubble_branch_inst1_MEM(1) <= '1' when branch_decision(0) = '1' or uins_EX(0).instruction = JALR else
                                  '0'; -- bubble in inst1_MEM when inst0_EX have a branch and is taken

    forwarding_unit_i: entity work.Forwarding_unit(arch1)
        generic map (
            ISSUE_WIDTH  => ISSUE_WIDTH
        )
        port map (
            RegWrite_stage_MEM_0  => uins_MEM(0).RegWrite,
            RegWrite_stage_MEM_1  => uins_MEM(1).RegWrite,
            RegWrite_stage_WB_0   => uins_WB(0).RegWrite,
            RegWrite_stage_WB_1   => uins_WB(1).RegWrite,
            rs1_stage_EX          => rs1_EX,
            rs2_stage_EX          => rs2_EX,
            rs1_stage_ID          => rs1_ID,
            rs2_stage_ID          => rs2_ID,
            rd_stage_MEM          => rd_MEM,
            rd_stage_WB           => rd_WB,
            ForwardA              => ForwardA,     -- Bypass ALU
            ForwardB              => ForwardB,     -- Bypass ALU
            ForwardWb_A           => ForwardWb_A,  -- INS_WB => write reg X, INS_ID => read reg X
            ForwardWb_B           => ForwardWb_B   -- INS_WB => write reg X, INS_ID => read reg X
        );
    
    -- Hazard Detection Unit
    HazardDetection_unit_i: entity work.HazardDetection_unit(arch1)
        generic map (
            ISSUE_WIDTH  => ISSUE_WIDTH
        )
        port map (
            rs2_ID               => rs2_ID,
            rs1_ID               => rs1_ID,
            rd_EX                => rd_EX,
            MemToReg_EX_0        => uins_EX(0).MemToReg,
            MemToReg_EX_1        => uins_EX(1).MemToReg,
            ce_pc                => ce_pc_hazard,
            ce_stage_ID          => ce_stage_ID_hazard,
            bubble_hazard_EX     => bubble_hazard_EX
        );

    CSR_unit_i: entity work.CSR_module(behavioral)
        port map (
            clock           => clock,
            reset           => reset,
            uins_WB         => uins_WB,
            csr_WB          => csr_WB,     -- CSR address in WB stage
            CSR_DATA_WB     => CSR_DATA_WB -- Data to write in CSR from WB stage
        );

    -------------------------------------------------------------------------------------------------------------------

    ------------------------------------------- DUPLICATE COMPONENTS --------------------------------------------------

    gen_duplicate : for i in 0 to ISSUE_WIDTH-1 generate

        -- ALU output address the data memory
        dataAddress(i) <= result_MEM(i);

        -- MemWrite receive signal of Stage MEM
        MemWrite(i) <= uins_MEM(i).MemWrite;

        rs1_ID(i) <= instruction_ID(i)(19 downto 15);
        rs2_ID(i) <= instruction_ID(i)(24 downto 20);
        rd_ID(i)  <= instruction_ID(i)(11 downto 7);

        -- Stage Instruction Decode of Pipeline
        IMM_DATA_EXTRACT_i: entity work.ImmediateDataExtractor(arch2)
        port map (
            instruction      => instruction_ID(i)(31 downto 7),
            instruction_f    => uins_ID(i).format,
            imm_data         => imm_data_ID(i)
        );

        --████████████████████████████████████████████████████████████████████████████████████████
        --██                                                                                    ██
        --██ ██╗██████═╗        ████████╗███████╗ ██████╗ ██╗███████╗████████╗███████╗████████╗ ██
        --██ ██║██╔══██╚╗       ██╔═══██║██╔════╝██╔════╝ ██║██╔════╝╚══██╔══╝██╔════╝██╔═══██║ ██
        --██ ██║██║   ██║       ████████║██████╗ ██║  ███╗██║███████╗   ██║   ██████╗ ████████║ ██
        --██ ██║██║  ██╔╝       ██╔══██╚╗██╔═══╝ ██║   ██║██║╚════██║   ██║   ██╔═══╝ ██╔══██╚╗ ██
        --██ ██║██████╔╝        ██║   ██║███████╗╚██████╔╝██║███████║   ██║   ███████╗██║   ██║ ██
        --██ ╚═╝╚═════╝         ╚═╝   ╚═╝╚══════╝ ╚═════╝ ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝   ╚═╝ ██
        --████████████████████████████████████████████████████████████████████████████████████████

        -- Stage Instruction Decode of Pipeline
        id_i: entity work.Stage_ID(behavioral)
            port map (
                clock               => clock, 
                reset               => reset,
                valid               => valid_ID(i),
                ce                  => ce_stage_ID(i),  
                pc_in               => PC_IF(i), 
                pc_out              => PC_ID(i),
                instruction_in      => instruction_IF(i),
                instruction_out     => instruction_ID(i),
                branch_taken_in     => btb_predict_taken_IF(i),
                branch_taken_out    => btb_predict_taken_ID(i)
            ); 

        --██████████████████████████████████████████████████████████████████████████████████████████████
        --██                                                                                          ██
        --██ ███████╗██╗    ██╗       ████████╗███████╗ ██████╗ ██╗███████╗████████╗███████╗████████╗ ██
        --██ ██╔════╝ ╚██ ██╔╝        ██╔═══██║██╔════╝██╔════╝ ██║██╔════╝╚══██╔══╝██╔════╝██╔═══██║ ██
        --██ ██████╗   ╚███╗          ████████║██████╗ ██║  ███╗██║███████╗   ██║   ██████╗ ████████║ ██
        --██ ██╔═══╝  ╔██ ██╗         ██╔══██╚╗██╔═══╝ ██║   ██║██║╚════██║   ██║   ██╔═══╝ ██╔══██╚╗ ██
        --██ ███████╗██╔╝   ██╗       ██║   ██║███████╗╚██████╔╝██║███████║   ██║   ███████╗██║   ██║ ██
        --██ ╚══════╝╚═╝    ╚═╝       ╚═╝   ╚═╝╚══════╝ ╚═════╝ ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝   ╚═╝ ██
        --██████████████████████████████████████████████████████████████████████████████████████████████

        -- Stage Exexution of Pipeline
        ex_i: entity work.Stage_EX(behavioral)
            port map (
                clock                 => clock, 
                reset                 => reset,
                valid                 => valid_EX(i),
                pc_in                 => PC_ID(i),
                pc_out                => PC_EX(i),
                read_data_1_in        => Data1_ID(i), 
                read_data_1_out       => readData1_EX(i),
                read_data_2_in        => Data2_ID(i), 
                read_data_2_out       => readData2_EX(i),
                imm_data_in           => imm_data_ID(i), 
                imm_data_out          => imm_data_EX(i),
                rs2_in                => rs2_ID(i), 
                rs2_out               => rs2_EX(i),
                rs1_in                => rs1_ID(i), 
                rs1_out               => rs1_EX(i),
                rd_in                 => rd_ID(i),  
                rd_out                => rd_EX(i),
                uins_in               => uins_ID(i), 
                uins_out              => uins_EX(i),
                branch_taken_in       => btb_predict_taken_ID(i),
                branch_taken_out      => btb_predict_taken_EX(i)
            );

        --██████████████████████████████████████████████████████████████████████████████████████████████████████████
        --██                                                                                                      ██
        --██ ███╗   ███╗███████╗███╗   ███╗       ████████╗███████╗ ██████╗ ██╗███████╗████████╗███████╗████████╗ ██
        --██ ████╗ ████║██╔════╝████╗ ████║       ██╔═══██║██╔════╝██╔════╝ ██║██╔════╝╚══██╔══╝██╔════╝██╔═══██║ ██
        --██ ██╔████╔██║██████╗ ██╔████╔██║       ████████║██████╗ ██║  ███╗██║███████╗   ██║   ██████╗ ████████║ ██
        --██ ██║╚██╔╝██║██╔═══╝ ██║╚██╔╝██║       ██╔══██╚╗██╔═══╝ ██║   ██║██║╚════██║   ██║   ██╔═══╝ ██╔══██╚╗ ██
        --██ ██║ ╚═╝ ██║███████╗██║ ╚═╝ ██║       ██║   ██║███████╗╚██████╔╝██║███████║   ██║   ███████╗██║   ██║ ██
        --██ ╚═╝     ╚═╝╚══════╝╚═╝     ╚═╝       ╚═╝   ╚═╝╚══════╝ ╚═════╝ ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝   ╚═╝ ██
        --██████████████████████████████████████████████████████████████████████████████████████████████████████████

        -- Stage Memory of Pipeline
        mem_i: entity work.Stage_MEM(behavioral)
            port map (
                clock            => clock, 
                reset            => reset,
                valid            => valid_MEM(i),
                alu_result_in    => result_EX(i),
                alu_result_out   => result_MEM(i),
                write_data_in    => operand2(i),
                write_data_out   => data_o(i),
                rd_in            => rd_EX(i),
                rd_out           => rd_MEM(i),
                CSR_in           => imm_data_EX(i)(11 downto 0),
                CSR_out          => CSR_MEM(i),
                uins_in          => uins_EX(i),
                uins_out         => uins_MEM(i)
            );
        
        --█████████████████████████████████████████████████████████████████████████████████████████████████
        --██                                                                                             ██
        --██ ██╗  ██╗  ██╗███████╗       ████████╗███████╗ ██████╗ ██╗███████╗████████╗███████╗████████╗ ██
        --██ ██║  ██║  ██║██╔══██║       ██╔═══██║██╔════╝██╔════╝ ██║██╔════╝╚══██╔══╝██╔════╝██╔═══██║ ██
        --██ ██║  ██║  ██║██████╔╝       ████████║██████╗ ██║  ███╗██║███████╗   ██║   ██████╗ ████████║ ██
        --██ ╚██═████═██╔╝██╔══██╗       ██╔══██╚╗██╔═══╝ ██║   ██║██║╚════██║   ██║   ██╔═══╝ ██╔══██╚╗ ██
        --██  ╚═██╔══██╔╝ ██████╔╝       ██║   ██║███████╗╚██████╔╝██║███████║   ██║   ███████╗██║   ██║ ██
        --██    ╚═╝  ╚═╝  ╚═════╝        ╚═╝   ╚═╝╚══════╝ ╚═════╝ ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝   ╚═╝ ██
        --█████████████████████████████████████████████████████████████████████████████████████████████████

        -- Stage Write Back of Pipeline
        wb_i: entity work.Stage_WB(behavioral)
            port map (
                clock            => clock, 
                reset            => reset,
                rd_in            => rd_MEM(i),
                rd_out           => rd_WB(i),
                read_data_in     => data_i(i), 
                read_data_out    => data_i_WB(i),
                alu_result_in    => result_MEM(i),
                alu_result_out   => result_WB(i),
                CSR_in           => CSR_MEM(i),
                CSR_out          => CSR_WB(i),
                uins_in          => uins_MEM(i),
                uins_out         => uins_WB(i)
            );

        --███████████████████████████████
        --██                           ██
        --██  █████╗ ██╗     ██╗   ██╗ ██
        --██ ██╔══██╗██║     ██║   ██║ ██
        --██ ███████║██║     ██║   ██║ ██
        --██ ██╔══██║██║     ██║   ██║ ██
        --██ ██║  ██║███████╗╚██████╔╝ ██
        --██ ╚═╝  ╚═╝╚══════╝ ╚═════╝  ██
        --███████████████████████████████

        -- Arithmetic/Logic Unit
        ALU_i: entity work.ALU(behavioral)
            port map (
                operand1          => operand1(i),
                operand2          => ALUoperand2(i),
                pc                => PC_EX(i),
                result            => result_EX(i),
                branch_prediction => btb_predict_taken_EX(i),
                branch_decision   => branch_decision(i),
                bubble_branch     => bubble_branch(i),
                operation         => uins_EX(i).instruction
            );
        
        -- Branch or Jump target address
        -- Branch ADDER
        ADDER_BRANCH: branchTarget(i) <= STD_LOGIC_VECTOR(UNSIGNED(PC_EX(i)) + UNSIGNED(imm_data_EX(i)));

        jumpTarget(i) <= STD_LOGIC_VECTOR(UNSIGNED(imm_data_EX(i)) + UNSIGNED(readData1_EX(i)));
        
        -- Selects the second ALU operand
        -- MUX at the ALU input
        MUX_ALU: ALUoperand2(i) <= operand2(i) when uins_EX(i).ALUSrc = '0' else
                                   imm_data_EX(i);
        
        -- Selects the data to be written in the register file
        -- MUX at the data memory output
        MUX_DATA_MEM: writeData(i) <= CSR_DATA_WB(i) when uins_WB(i).instruction = CSRRS else -- CHANGE WHEN ALL THE CSR INSTRUCTION WILL BE IMPLEMENTED
                                      data_i_WB(i)   when uins_WB(i).memToReg = '1' else 
                                      result_WB(i);

        --███████████████████████████████████████████████████████████████████████████████████████████████████████████████████
        --██                                                                                                               ██
        --██ ███████╗ ██████╗ ████████╗██╗  ██╗  ██╗ █████╗ ████████╗██████═╗        ██╗      ██████╗  ██████╗ ██╗███████╗ ██
        --██ ██╔════╝██╔═══██╗██╔═══██║██║  ██║  ██║██╔══██╗██╔═══██║██╔══██╚╗       ██║     ██╔═══██╗██╔════╝ ██║██╔════╝ ██
        --██ ██████╗ ██║   ██║████████║██║  ██║  ██║███████║████████║██║   ██║       ██║     ██║   ██║██║  ███╗██║██║      ██
        --██ ██╔═══╝ ██║   ██║██╔══██╚╗╚██═████═██╔╝██╔══██║██╔══██╚╗██║  ██╔╝       ██║     ██║   ██║██║   ██║██║██║      ██
        --██ ██║     ╚██████╔╝██║   ██║ ╚═██╔══██╔╝ ██║  ██║██║   ██║██████╔╝        ███████╗╚██████╔╝╚██████╔╝██║███████╗ ██
        --██ ╚═╝      ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝  ╚═╝  ╚═╝╚═╝   ╚═╝╚═════╝         ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝╚══════╝ ██
        --███████████████████████████████████████████████████████████████████████████████████████████████████████████████████

        -- MUX Forward A (operand ALU)
        MUX_FORWARD_A: operand1(i) <= result_MEM(0) when ForwardA(i) = "010" else -- Bypass operand1 INS_EX(i) <- INS_MEM(0)
                                      writeData(0)  when ForwardA(i) = "001" else -- Bypass operand1 INS_EX(i) <- INS_WB(0)
                                      result_MEM(1) when ForwardA(i) = "011" else -- Bypass operand1 INS_EX(i) <- INS_MEM(1) 
                                      writeData(1)  when ForwardA(i) = "100" else -- Bypass operand1 INS_EX(i) <- INS_WB(1)
                                      readData1_EX(i);                            -- No Bypass

        -- MUX Forward B (operand ALU) 
        MUX_FORWARD_B: operand2(i) <= result_MEM(0) when ForwardB(i) = "010" else -- Bypass operand2 INS_EX(i) <- INS_MEM(0)
                                      writeData(0)  when ForwardB(i) = "001" else -- Bypass operand2 INS_EX(i) <- INS_WB(0)
                                      result_MEM(1) when ForwardB(i) = "011" else -- Bypass operand2 INS_EX(i) <- INS_MEM(1) 
                                      writeData(1)  when ForwardB(i) = "100" else -- Bypass operand2 INS_EX(i) <- INS_WB(1)
                                      readData2_EX(i);                            -- No Bypass

        -- MUX Forward WB A
        MUX_FORWARD_WB_A: Data1_ID(i) <= writeData(0) when ForwardWb_A(i) = "01" else -- Bypass rs1 INS_ID(0) <- INS_WB(0) 
                                         writeData(1) when ForwardWb_A(i) = "10" else -- Bypass rs1 INS_ID(0) <- INS_WB(1)
                                         readData1_ID(i);                             -- No Bypass

        -- MUX Forward WB B
        MUX_FORWARD_WB_B: Data2_ID(i) <= writeData(0) when ForwardWb_B(i) = "01" else -- Bypass rs2 INS_ID(i) <- INS_WB(0) 
                                         writeData(1) when ForwardWb_B(i) = "10" else -- Bypass rs2 INS_ID(i) <- INS_WB(1)
                                         readData2_ID(i);                             -- No Bypass
        
        --████████████████████████████████████████████████████████████████████████████████████████████████████████
        --██                                                                                                    ██
        --██ ██╗   ██╗ █████╗ ██╗     ██╗██████═╗        ███████╗██╗ ██████╗ ███╗   ██╗ █████╗ ██╗     ███████╗ ██
        --██ ██║   ██║██╔══██╗██║     ██║██╔══██╚╗       ██╔════╝██║██╔════╝ ████╗  ██║██╔══██╗██║     ██╔════╝ ██
        --██ ██║   ██║███████║██║     ██║██║   ██║       ███████╗██║██║  ███╗██╔██╗ ██║███████║██║     ███████╗ ██
        --██ ╚██║ ██╔╝██╔══██║██║     ██║██║  ██╔╝       ╚════██║██║██║   ██║██║╚██╗██║██╔══██║██║     ╚════██║ ██
        --██  ╚████╔╝ ██║  ██║███████╗██║██████╔╝        ███████║██║╚██████╔╝██║ ╚████║██║  ██║███████╗███████║ ██
        --██   ╚═══╝  ╚═╝  ╚═╝╚══════╝╚═╝╚═════╝         ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚══════╝ ██
        --████████████████████████████████████████████████████████████████████████████████████████████████████████

        valid_ID(i) <= bubble_branch(0) = '0' and (bubble_branch(1) = '0' or branch_decision(0) = '1') and bubble_dep_inst0_ID(i) = '0' and uins_EX(0).instruction /= JALR and uins_EX(1).instruction /= JALR;

        valid_EX(i) <= bubble_hazard_EX = '0' and bubble_dep_inst1_EX(i) = '0' and bubble_branch(0) = '0' and (bubble_branch(1) = '0' or branch_decision(0) = '1') and uins_EX(0).instruction /= JALR and uins_EX(1).instruction /= JALR;

        valid_MEM(i) <= bubble_branch_inst1_MEM(i) = '0';

    end generate;


--██████████████████████████████████████████████████████████████████████████████████████████████████████████████
--██                                                                                                          ██
--██ ██████═╗ ███████╗███████╗██╗   ██╗ ██████╗        ███████╗██╗ ██████╗ ███╗   ██╗ █████╗ ██╗     ███████╗ ██
--██ ██╔══██╚╗██╔════╝██╔══██║██║   ██║██╔════╝        ██╔════╝██║██╔════╝ ████╗  ██║██╔══██╗██║     ██╔════╝ ██
--██ ██║   ██║██████╗ ██████╔╝██║   ██║██║  ███╗       ███████╗██║██║  ███╗██╔██╗ ██║███████║██║     ███████╗ ██
--██ ██║  ██╔╝██╔═══╝ ██╔══██╗██║   ██║██║   ██║       ╚════██║██║██║   ██║██║╚██╗██║██╔══██║██║     ╚════██║ ██
--██ ██████╔╝ ███████╗██████╔╝╚██████╔╝╚██████╔╝       ███████║██║╚██████╔╝██║ ╚████║██║  ██║███████╗███████║ ██
--██ ╚═════╝  ╚══════╝╚═════╝  ╚═════╝  ╚═════╝        ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚══════╝ ██
--██████████████████████████████████████████████████████████████████████████████████████████████████████████████


    DECODE_STAGE_IF: -- Decoded Instruction of Instruction Fetch Stage for SIMULATION
    if not SYNTHESIS generate
    
        gen_tb : for k in 0 to ISSUE_WIDTH-1 generate

            opcode(k) <= instruction_IF(k)(6 downto 0);
            funct3(k) <= instruction_IF(k)(14 downto 12);
            funct7(k) <= instruction_IF(k)(31 downto 25);

            -- Instruction format decode
            decodedFormat_IF(k) <= U when opcode(k) = "0010111" or opcode(k) = "0110111" else
                            J when opcode(k) = "1101111" else
                            I when opcode(k) = "1100111" or opcode(k) = "1100111" or opcode(k) = "1110011" or opcode(k) = "0001111" else
                            B when opcode(k) = "1100011" else
                            R when opcode(k) = "0110011" else
                            S when opcode(k) = "0100011" else
                            X; -- invalid format

            -- Instruction type decode
            decodedInstruction_IF(k) <=   -- U-format 
                                    LUI     when decodedFormat_IF(k) = U and opcode(k)(5) = '1' else
                                    AUIPC   when decodedFormat_IF(k) = U and opcode(k)(5) = '0' else
                                    -- J-format
                                    JAL     when decodedFormat_IF(k) = J else
                                    -- I-format
                                    JALR    when opcode(k) = "1100111" else 
                                    -- B-format
                                    BEQ     when decodedFormat_IF(k) = B and funct3(k) = "000" else
                                    BNE     when decodedFormat_IF(k) = B and funct3(k) = "001" else
                                    BLT     when decodedFormat_IF(k) = B and funct3(k) = "100" else
                                    BGE     when decodedFormat_IF(k) = B and funct3(k) = "101" else 
                                    BLTU    when decodedFormat_IF(k) = B and funct3(k) = "110" else
                                    BGEU    when decodedFormat_IF(k) = B and funct3(k) = "111" else 
                                    -- I-format
                                    LB      when opcode(k) = "0000011" and funct3(k) = "000" else 
                                    LH      when opcode(k) = "0000011" and funct3(k) = "001" else
                                    LW      when opcode(k) = "0000011" and funct3(k) = "010" else
                                    LBU     when opcode(k) = "0000011" and funct3(k) = "100" else
                                    LHU     when opcode(k) = "0000011" and funct3(k) = "101" else
                                    -- S-format
                                    SB      when decodedFormat_IF(k) = S and funct3(k) = "000" else
                                    SH      when decodedFormat_IF(k) = S and funct3(k) = "001" else
                                    SW      when decodedFormat_IF(k) = S and funct3(k) = "010" else
                                    -- I-format
                                    ADDI    when opcode(k) = "0010011" and funct3(k) = "000" else
                                    SLTI    when opcode(k) = "0010011" and funct3(k) = "010" else
                                    SLTIU   when opcode(k) = "0010011" and funct3(k) = "011" else
                                    XORI    when opcode(k) = "0010011" and funct3(k) = "100" else 
                                    ORI     when opcode(k) = "0010011" and funct3(k) = "110" else
                                    ANDI    when opcode(k) = "0010011" and funct3(k) = "111" else
                                    SLLI    when opcode(k) = "0010011" and funct3(k) = "001" else
                                    SRLI    when opcode(k) = "0010011" and funct3(k) = "101" and funct7(k)(5) = '0' else
                                    SRAI    when opcode(k) = "0010011" and funct3(k) = "101" and funct7(k)(5) = '1' else
                                    -- R-format
                                    ADD     when decodedFormat_IF(k) = R and funct3(k) = "000" and funct7(k)(5) = '0' else
                                    SUB     when decodedFormat_IF(k) = R and funct3(k) = "000" and funct7(k)(5) = '1' else
                                    SLLL    when decodedFormat_IF(k) = R and funct3(k) = "001" else
                                    SLT     when decodedFormat_IF(k) = R and funct3(k) = "010" else
                                    SLTU    when decodedFormat_IF(k) = R and funct3(k) = "011" else
                                    XORR    when decodedFormat_IF(k) = R and funct3(k) = "100" else
                                    SRLL    when decodedFormat_IF(k) = R and funct3(k) = "101" and funct7(k)(5) = '0' else
                                    SRAA    when decodedFormat_IF(k) = R and funct3(k) = "101" and funct7(k)(5) = '1' else
                                    ORR     when decodedFormat_IF(k) = R and funct3(k) = "110" else
                                    ANDD    when decodedFormat_IF(k) = R and funct3(k) = "111" else
                                    -- FENCE instructions
                                    FENCE   when opcode(k) = "0001111" and funct3(k) = "000" else
                                    FENCE_I when opcode(k) = "0001111" and funct3(k) = "001" else
                                    -- SYSTEM instruction
                                    ECALL   when opcode(k) = "1110011" and funct3(k) = "000" and instruction_IF(k)(20) = '0' else
                                    EBREAK  when opcode(k) = "1110011" and funct3(k) = "000" and instruction_IF(k)(20) = '1' else
                                    -- CSR instructions
                                    CSRRW   when opcode(k) = "1110011" and funct3(k) = "001" else 
                                    CSRRS   when opcode(k) = "1110011" and funct3(k) = "010" else
                                    CSRRC   when opcode(k) = "1110011" and funct3(k) = "011" else
                                    CSRRWI  when opcode(k) = "1110011" and funct3(k) = "101" else
                                    CSRRSI  when opcode(k) = "1110011" and funct3(k) = "101" else
                                    CSRRCI  when opcode(k) = "1110011" and funct3(k) = "111" else

                                    -- Invalid or not implemented instruction
                                    INVALID_INSTRUCTION; 
        end generate;
    end generate;

end structural;