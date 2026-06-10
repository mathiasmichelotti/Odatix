-------------------------------------------------------------------------
-- Design unit: Double Issue Dep
-- Description: Detects data dependency between the operands in 
-- inst[0] and inst[1], in the ID stage, and makes a stall in inst[1].
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all; 


entity Double_issue_dep is
    port (
        rs1_inst1           : in  std_logic_vector (4 downto 0);
        rs2_inst1           : in  std_logic_vector (4 downto 0);
        rd_inst0            : in  std_logic_vector (4 downto 0);
        ce_pc               : out std_logic;
        ce_stage_ID         : out std_logic;
        bubble_dep_inst1_EX : out std_logic;
        bubble_dep_inst0_ID : out std_logic
    );
end Double_issue_dep;


architecture arch1 of Double_issue_dep is

    signal ce : std_logic;
    
begin

    ce <= '0' when (rd_inst0 = rs1_inst1 or rd_inst0 = rs2_inst1) and rd_inst0 /= "00000" else
          '1';

    ce_pc <= ce;
    ce_stage_ID <= ce;
    bubble_dep_inst1_EX <= not ce;
    bubble_dep_inst0_ID <= not ce;
    
end arch1;
