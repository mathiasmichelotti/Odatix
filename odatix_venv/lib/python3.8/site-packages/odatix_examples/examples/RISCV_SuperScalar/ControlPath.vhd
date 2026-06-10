-------------------------------------------------------------------------
-- Design unit: Control path
-- Description: RISCV control path 2 intructions decode
-- supporting LUI, AUIPC, JAL, JALR, BEQ, 
-- BNE, BLT, BGE, BLTU, BGEU, LB, LH, LW, LBU, LHU, SB, SH, SW, ADDI, SLTI, 
-- SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI, ADD, SUB, SLLL, SLT, SLTU, XORR, 
-- SRLL, SRAA, ORR, ANDD, FENCE, FENCE_i, ECALL, EBREAK, CSRRW, CSRRS, CSRRC, 
-- CSRRWI, CSRRSI, CSRRCI instructions.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.RISCV_package.all;


entity ControlPath is
    generic (
        INST_WIDTH    : integer := 64;
        ISSUE_WIDTH   : natural := 2
    );
    port (  
        clock           : in  std_logic;
        reset           : in  std_logic;
        instruction     : in  Data_array;
        uins            : out Microinstruction_array
    );
end ControlPath;
                   

architecture behavioral of ControlPath is
    
begin

    decode_gen : for i in 0 to ISSUE_WIDTH-1 generate
        decode_i: entity work.Decode_Unit(behavioral)
         port map (
             clock          => clock,
             reset          => reset,
             instruction    => instruction(i),
             uins           => uins(i)
         );
    end generate;

end behavioral;
