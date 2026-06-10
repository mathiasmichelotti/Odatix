-------------------------------------------------------------------------
-- Design unit: MIPS Pipeline 
-- Description: Control and data paths port map
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.RISCV_package.all;

entity RISCV_superscalar is
    generic (
        PC_START_ADDRESS    : integer := 4194304;
        DATA_WIDTH          : integer := 32;
        INST_WIDTH          : integer := 64;
        SYNTHESIS           : boolean := false;
        ISSUE_WIDTH         : natural := 2
    );
    port ( 
        clock, reset        : in std_logic;
        
        -- Instruction memory interface
        instructionAddress  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        instruction         : in  std_logic_vector(INST_WIDTH-1 downto 0);
        
        -- Data memory interface
        dataAddress         : out Data_array;
        data_i              : in  Data_array;      
        data_o              : out Data_array;
        MemWrite            : out MemWrite_array 
    );
end RISCV_superscalar;

architecture structural of RISCV_superscalar is
    
    signal uins : Microinstruction_array;
    signal instructions_to_decode : Data_array;

begin

     CONTROL_PATH: entity work.ControlPath(behavioral)
         generic map (
            INST_WIDTH  => INST_WIDTH, 
            ISSUE_WIDTH => ISSUE_WIDTH
        )
         port map (
             clock          => clock,
             reset          => reset,
             instruction    => instructions_to_decode,
             uins           => uins
         );
         
         
     DATA_PATH: entity work.DataPath(structural)
         generic map (
            PC_START_ADDRESS => PC_START_ADDRESS,
            SYNTHESIS        => SYNTHESIS,
            DATA_WIDTH       => DATA_WIDTH,
            INST_WIDTH       => INST_WIDTH,
            ISSUE_WIDTH      => ISSUE_WIDTH
         )
         port map (
            clock               => clock,
            reset               => reset,
            
            uins_ID             => uins,
             
            instructionAddress  => instructionAddress,
            instruction_in      => instruction,
            instruction_out     => instructions_to_decode,
             
            dataAddress         => dataAddress,
            data_i              => data_i,
            data_o              => data_o,
            MemWrite            => MemWrite
         );
     
end structural;