-------------------------------------------------------------------------
-- Design unit: Forwarding Unit
-- Description: Detects data dependency between the ALU operands in the 
-- EX stage and the write registers in the MEM and WB stages.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all; 
use work.RISCV_package.all;

entity Forwarding_unit is
    generic (
        ISSUE_WIDTH         : natural := 2
    );
    port (
        RegWrite_stage_MEM_0 : in  std_logic;
        RegWrite_stage_MEM_1 : in  std_logic;
        RegWrite_stage_WB_0  : in  std_logic;
        RegWrite_stage_WB_1  : in  std_logic;
        rs1_stage_EX         : in  Reg_array;
        rs2_stage_EX         : in  Reg_array;
        rs1_stage_ID         : in  Reg_array;
        rs2_stage_ID         : in  Reg_array;
        rd_stage_MEM         : in  Reg_array;
        rd_stage_WB          : in  Reg_array;
        ForwardA             : out Select_array_3b;
        ForwardB             : out Select_array_3b;
        ForwardWb_A          : out Select_array_2b;
        ForwardWb_B          : out Select_array_2b    
    );
end Forwarding_unit;

architecture arch1 of Forwarding_unit is
begin
    gen_forward : for i in 0 to ISSUE_WIDTH-1 generate
    
        ForwardA(i) <= "010" when RegWrite_stage_MEM_0 = '1' and rd_stage_MEM(0) /= "00000" and rd_stage_MEM(0) = rs1_stage_EX(i) else -- Bypass rs1 INS_EX(i) <- INS_MEM(0)
                       "011" when RegWrite_stage_MEM_1 = '1' and rd_stage_MEM(1) /= "00000" and rd_stage_MEM(1) = rs1_stage_EX(i) else -- Bypass rs1 INS_EX(i) <- INS_MEM(1) 
                       "001" when RegWrite_stage_WB_0  = '1' and rd_stage_WB(0)  /= "00000" and rd_stage_WB(0)  = rs1_stage_EX(i) else -- Bypass rs1 INS_EX(i) <- INS_WB(0)  
                       "100" when RegWrite_stage_WB_1  = '1' and rd_stage_WB(1)  /= "00000" and rd_stage_WB(1)  = rs1_stage_EX(i) else -- Bypass rs1 INS_EX(i) <- INS_WB(1)
                       "000";                                                                                                           -- No Bypass

        ForwardB(i) <= "010" when RegWrite_stage_MEM_0 = '1' and rd_stage_MEM(0) /= "00000" and rd_stage_MEM(0) = rs2_stage_EX(i) else -- Bypass rs2 INS_EX(i) <- INS_MEM(0)
                       "011" when RegWrite_stage_MEM_1 = '1' and rd_stage_MEM(1) /= "00000" and rd_stage_MEM(1) = rs2_stage_EX(i) else -- Bypass rs2 INS_EX(i) <- INS_MEM(1) 
                       "001" when RegWrite_stage_WB_0  = '1' and rd_stage_WB(0)  /= "00000" and rd_stage_WB(0)  = rs2_stage_EX(i) else -- Bypass rs2 INS_EX(i) <- INS_WB(0)  
                       "100" when RegWrite_stage_WB_1  = '1' and rd_stage_WB(1)  /= "00000" and rd_stage_WB(1)  = rs2_stage_EX(i) else -- Bypass rs2 INS_EX(i) <- INS_WB(1)
                       "000";                                                                                                           -- No Bypass
        
        ForwardWb_A(i) <= "01" when RegWrite_stage_WB_0 = '1' and rd_stage_WB(0) = rs1_stage_ID(i) and rd_stage_WB(0) /= "00000" else -- Bypass rs1 INS_ID(i) <- INS_WB(0) 
                          "10" when RegWrite_stage_WB_1 = '1' and rd_stage_WB(1) = rs1_stage_ID(i) and rd_stage_WB(1) /= "00000" else -- Bypass rs1 INS_ID(i) <- INS_WB(1) 
                          "00";                                                                                                       -- No Bypass
        
        ForwardWb_B(i) <= "01" when RegWrite_stage_WB_0 = '1' and rd_stage_WB(0) = rs2_stage_ID(i) and rd_stage_WB(0) /= "00000" else -- Bypass rs2 INS_ID(i) <- INS_WB(0) 
                          "10" when RegWrite_stage_WB_1 = '1' and rd_stage_WB(1) = rs2_stage_ID(i) and rd_stage_WB(1) /= "00000" else -- Bypass rs2 INS_ID(i) <- INS_WB(1) 
                          "00";                                                                                                       -- No Bypass
    end generate;
end arch1;