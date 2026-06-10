-------------------------------------------------------------------------
-- Design unit: CSR Registers Module
-- Description: 
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.RISCV_package.all;


entity CSR_module is
    port (  
        clock           : in  std_logic;
        reset           : in  std_logic;
        uins_WB         : in  Microinstruction_array;
        csr_WB          : in  CSR_array;  -- CSR address in WB stage
        CSR_DATA_WB     : out Data_array  -- Data to write in CSR from WB stage
    );
end CSR_module;

architecture behavioral of CSR_module is

    -- CSR Registers
    signal CSR_cycles : std_logic_vector(63 downto 0);
    signal CSR_inst   : std_logic_vector(63 downto 0);
    
begin

    process(clock, reset) begin 
        if reset = '1' then
            CSR_cycles <= (others=>'0');
            CSR_inst <= (others=>'0');

        elsif rising_edge(clock) then
            CSR_cycles <= STD_LOGIC_VECTOR(UNSIGNED(CSR_cycles) + TO_UNSIGNED(1,64));

            if uins_WB(0).instruction /= INVALID_INSTRUCTION and uins_WB(1).instruction /= INVALID_INSTRUCTION then
                CSR_inst <= STD_LOGIC_VECTOR(UNSIGNED(CSR_inst) + TO_UNSIGNED(2,64));
            
            elsif (uins_WB(0).instruction /= INVALID_INSTRUCTION and uins_WB(1).instruction = INVALID_INSTRUCTION) or (uins_WB(0).instruction = INVALID_INSTRUCTION and uins_WB(1).instruction /= INVALID_INSTRUCTION) then
                CSR_inst <= STD_LOGIC_VECTOR(UNSIGNED(CSR_inst) + TO_UNSIGNED(1,64));

            end if;
        end if;
    end process;


    CSR_DATA_WB(0) <= CSR_cycles(31 downto 0)  when uins_WB(0).instruction = CSRRS and csr_WB(0) = x"C00" else
                      CSR_cycles(63 downto 32) when uins_WB(0).instruction = CSRRS and csr_WB(0) = x"C80" else
                      CSR_inst(31 downto 0)    when uins_WB(0).instruction = CSRRS and csr_WB(0) = x"C02" else
                      CSR_inst(63 downto 32)   when uins_WB(0).instruction = CSRRS and csr_WB(0) = x"C82" else
                      (others => '0');
    
    CSR_DATA_WB(1) <= CSR_cycles(31 downto 0)  when uins_WB(1).instruction = CSRRS and csr_WB(1) = x"C00" else
                      CSR_cycles(63 downto 32) when uins_WB(1).instruction = CSRRS and csr_WB(1) = x"C80" else
                      CSR_inst(31 downto 0)    when uins_WB(1).instruction = CSRRS and csr_WB(1) = x"C02" else
                      CSR_inst(63 downto 32)   when uins_WB(1).instruction = CSRRS and csr_WB(1) = x"C82" else
                      (others => '0');

end behavioral;