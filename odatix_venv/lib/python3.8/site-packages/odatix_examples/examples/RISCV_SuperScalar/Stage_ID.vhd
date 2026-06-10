-------------------------------------------------------------------------
-- Design unit: Stage 1 (IF/ID)
-- Description: Register of Instruction Decode Stage data
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

   
entity Stage_ID is
    generic (
        INIT    : integer := 0
    );
    port (  
        clock               : in  std_logic;
        reset               : in  std_logic;
        valid               : in  boolean;
        ce                  : in  std_logic;  
	    pc_in               : in  std_logic_vector(31 downto 0);  
        pc_out              : out std_logic_vector(31 downto 0);
        instruction_in      : in  std_logic_vector(31 downto 0);  
        instruction_out     : out std_logic_vector(31 downto 0);
        branch_taken_in     : in  std_logic;
        branch_taken_out    : out std_logic                
    );
end Stage_ID;


architecture behavioral of Stage_ID is 

    signal pc, instruction : std_logic_vector(31 downto 0);
    signal branch_taken : std_logic;
    
begin

    pc <= pc_in when valid else (others => '0');

    -- PC register
    PC_REG:    entity work.RegisterNbits
        generic map (
            LENGTH      => 32,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => ce, 
            d           => pc, 
            q           => pc_out
        );
    
    instruction <= instruction_in when valid else (others => '0');
    
    -- Instruction register
    Instruction_REG:    entity work.RegisterNbits
        generic map (
            LENGTH      => 32,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => ce, 
            d           => instruction, 
            q           => instruction_out
        );

    branch_taken <= branch_taken_in when valid else '0';

    process(clock, reset)
    begin
        if reset = '1' then
            branch_taken_out <= '0';
        elsif rising_edge(clock) then
            if ce = '1' then
                branch_taken_out <= branch_taken;
            end if;
        end if;
    end process;
    
end behavioral;
