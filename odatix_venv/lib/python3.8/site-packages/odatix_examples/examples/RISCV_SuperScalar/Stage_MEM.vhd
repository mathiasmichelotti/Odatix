-------------------------------------------------------------------------
-- Design unit: Stage 3 (EX/MEM)
-- Description: Register of Memory (read an write) Stage data
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all; 
use work.RISCV_package.all;

   
entity Stage_MEM is
    generic (
        INIT    : integer := 0
    );
    port (  
        clock            : in  std_logic;
        reset            : in  std_logic;
        valid            : in  boolean;
	    alu_result_in    : in  std_logic_vector(31 downto 0);  
        alu_result_out   : out std_logic_vector(31 downto 0); 
	    write_data_in    : in  std_logic_vector(31 downto 0);  
        write_data_out   : out std_logic_vector(31 downto 0);
        rd_in            : in  std_logic_vector(4 downto 0); 
        rd_out           : out std_logic_vector(4 downto 0);
        CSR_in           : in  std_logic_vector(11 downto 0);
        CSR_out          : out std_logic_vector(11 downto 0);
        uins_in          : in  Microinstruction;
        uins_out         : out Microinstruction                
    );
end Stage_MEM;


architecture behavioral of Stage_MEM is 

    signal alu_result, write_data : std_logic_vector(31 downto 0);
    signal rd : std_logic_vector(4 downto 0);
    signal CSR : std_logic_vector(11 downto 0);
    signal uins, uins_bubble : Microinstruction;
    
begin

    alu_result <= alu_result_in when valid else (others => '0');

    -- ALU result register
    ALU_result_REG:    entity work.RegisterNbits
        generic map (
            LENGTH      => 32,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => alu_result, 
            q           => alu_result_out
        );

    write_data <= write_data_in when valid else (others => '0');

    -- Write data register
    Write_data_REG:    entity work.RegisterNbits
        generic map (
            LENGTH      => 32,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => write_data, 
            q           => write_data_out
        );
    
    rd <= rd_in when valid else (others => '0');

    -- register destination register
    RD_reg:    entity work.RegisterNbits
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
    
    csr <= CSR_in when valid else (others => '0');

     -- CSR register
    CSR_reg:    entity work.RegisterNbits
        generic map (
            LENGTH      => 12,
            INIT_VALUE  => INIT
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => CSR, 
            q           => CSR_out
        );
    
    uins <= uins_in when valid else uins_bubble;

    uins_bubble.RegWrite     <= '0';
    uins_bubble.ALUSrc       <= '0';
    uins_bubble.MemToReg     <= '0';
    uins_bubble.MemWrite     <= "0000";
    uins_bubble.format       <= X;
    uins_bubble.instruction  <= INVALID_INSTRUCTION;

    -- Control registers   
    process(clock, reset)
    begin
        if reset = '1' then
            uins_out.instruction <= INVALID_INSTRUCTION;
	        uins_out.RegWrite  <= '0';
            uins_out.MemWrite  <= "0000";
            uins_out.MemToReg  <= '0';     
        
        elsif rising_edge(clock) then
            uins_out.instruction <= uins.instruction;
	        uins_out.RegWrite    <= uins.RegWrite;
            uins_out.MemWrite    <= uins.MemWrite;
            uins_out.MemToReg    <= uins.MemToReg;
        end if;
    end process;
    
end behavioral;  
