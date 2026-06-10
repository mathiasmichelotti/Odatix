-------------------------------------------------------------------------
-- Design unit: Stage 2 (DEC/EXE)
-- Description: Register of Execution Stage data
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all; 
use work.RISCV_package.all;

   
entity Stage_EX is
    generic (
        INIT    : integer := 0
    );
    port (  
        clock                 : in  std_logic;
        reset                 : in  std_logic;
        valid                 : in  boolean;
        pc_in                 : in  std_logic_vector(31 downto 0);
        pc_out                : out std_logic_vector(31 downto 0);
        read_data_1_in        : in  std_logic_vector(31 downto 0);  
        read_data_1_out       : out std_logic_vector(31 downto 0); 
	    read_data_2_in        : in  std_logic_vector(31 downto 0);  
        read_data_2_out       : out std_logic_vector(31 downto 0); 
        imm_data_in           : in  std_logic_vector(31 downto 0); 
        imm_data_out          : out std_logic_vector(31 downto 0);
        rs1_in                : in  std_logic_vector(4 downto 0);
        rs1_out               : out std_logic_vector(4 downto 0);
        rs2_in                : in  std_logic_vector(4 downto 0);  
        rs2_out               : out std_logic_vector(4 downto 0);
        rd_in                 : in  std_logic_vector(4 downto 0);  
        rd_out                : out std_logic_vector(4 downto 0);
        branch_taken_in       : in  std_logic;
        branch_taken_out      : out std_logic;
        uins_in               : in  Microinstruction;
        uins_out              : out Microinstruction                
    );
end Stage_EX;


architecture behavioral of Stage_EX is 

    signal pc, read_data_1, read_data_2, imm_data : std_logic_vector(31 downto 0);
    signal rs1, rs2, rd : std_logic_vector(4 downto 0);
    signal uins, uins_bubble : Microinstruction;
    signal branch_taken : std_logic;
    
begin

    pc <= pc_in when valid else (others => '0');

    -- Read Data 1 register
    PC_REG:   entity work.RegisterNbits
        generic map (
            LENGTH      => 32,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => pc, 
            q           => pc_out
        );
    
    read_data_1 <= read_data_1_in when valid else (others => '0');

    -- Read Data 1 register
    Read_data_1_REG:   entity work.RegisterNbits
        generic map (
            LENGTH      => 32,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => read_data_1, 
            q           => read_data_1_out
        );

    read_data_2 <= read_data_2_in when valid else (others => '0');

    -- Read Data 2 register
    Read_data_2_REG:    entity work.RegisterNbits
        generic map (
            LENGTH      => 32,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => read_data_2, 
            q           => read_data_2_out
        );
    
    imm_data <= imm_data_in when valid else (others => '0');

    -- Imediate data register
    IMM_DATA_REG:    entity work.RegisterNbits
        generic map (
            LENGTH      => 32,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => imm_data, 
            q           => imm_data_out
        );

    rs2 <= rs2_in when valid else (others => '0');

    -- RS2 register
    RS2_REG:    entity work.RegisterNbits
        generic map (
            LENGTH      => 5,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => rs2, 
            q           => rs2_out
        );
    
    rd <= rd_in when valid else (others => '0');

    -- RD register
    RD_REG:    entity work.RegisterNbits
        generic map (
            LENGTH      => 5,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => rd, 
            q           => rd_out
        );

    rs1 <= rs1_in when valid else (others => '0');

    -- RS1 register
    RS1_REG:    entity work.RegisterNbits
        generic map (
            LENGTH      => 5,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => rs1, 
            q           => rs1_out
        );
    
    branch_taken <= branch_taken_in when valid else '0';

     -- Branch taken register
    process(clock, reset)
    begin
        if reset = '1' then
            branch_taken_out <= '0';
        elsif rising_edge(clock) then
            branch_taken_out <= branch_taken;
        end if;
    end process;

    uins <= uins_in when valid else uins_bubble;

    uins_bubble.RegWrite     <= '0';
    uins_bubble.ALUSrc       <= '0';
    uins_bubble.MemToReg     <= '0';
    uins_bubble.MemWrite     <= "0000";
    uins_bubble.format       <= X;
    uins_bubble.instruction  <= INVALID_INSTRUCTION;
    
    -- Control register   
    process(clock, reset)
    begin
        if reset = '1' then
            uins_out.instruction <= INVALID_INSTRUCTION;
	        uins_out.RegWrite    <= '0';
            uins_out.ALUSrc      <= '0';
            uins_out.MemWrite    <= "0000";
            uins_out.MemToReg    <= '0';
            uins_out.format      <= X;   
            
        elsif rising_edge(clock) then
            uins_out.instruction <= uins.instruction;
	        uins_out.RegWrite    <= uins.RegWrite;
            uins_out.ALUSrc      <= uins.ALUSrc;
            uins_out.MemWrite    <= uins.MemWrite;
            uins_out.MemToReg    <= uins.MemToReg;
            uins_out.format      <= uins.format;
        end if;
    end process;
    
end behavioral;
