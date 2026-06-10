library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.RISCV_package.all;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity BTB_superscalar is
    generic (
        BTB_BITS : integer := 4   -- 2^4 = 16 entradas
    );
    port (
        clock : in std_logic;
        reset : in std_logic;

        -- ===== FETCH (IF) =====
        pc_in : in data_array;

        predict_taken : out std_logic_vector (1 downto 0);

        predict_pc : out data_array;

        -- ===== UPDATE (EX) =====
        inst_format_0 : in Instruction_format;
        inst_format_1 : in Instruction_format;
        
        pc_update    : in  data_array;
        target_real  : in  data_array;
        taken_real   : in  std_logic_vector(1 downto 0)
    );
end BTB_superscalar;

architecture Behavioral of BTB_superscalar is

    constant BTB_SIZE : integer := 2**BTB_BITS;

    signal btb_valid : std_logic_vector(BTB_SIZE-1 downto 0);

    type btb_entry is record
        tag    : std_logic_vector(31 downto 0);
        target : std_logic_vector(31 downto 0);
        pred   : std_logic_vector(1 downto 0);
    end record;

    type btb_array is array (0 to BTB_SIZE-1) of btb_entry;
    
    -- Inicializa tudo com zero para matar o estado 'U' no simulador
    signal BTB : btb_array := (others => (tag => (others => '0'), 
                                          target => (others => '0'), 
                                          pred => "00"));

    
    type index_array is array (0 to 1) of integer range 0 to BTB_SIZE-1;

    signal index_fetch : index_array;
    signal hit         : std_logic_vector(1 downto 0);
    
    signal Branch_inst: std_logic_vector(1 downto 0);
    
begin

-- =========================================================
-- Branch Instruction Detection
-- =========================================================

Branch_inst(0) <= '1' when (inst_format_0 = B or inst_format_0 = J) else -- se o ce é '0' ocorre um stall, logo nao deve atualizar a tabela 
                  '0';                                                                            -- pois o branch ficara estagio no ID, e nao queremos atualizar 
                                                                                                  -- mais de uma vez para a mesma intrução

Branch_inst(1) <= '1' when (inst_format_1 = B or inst_format_1 = J) else
                  '0';

-- =========================================================
-- Index through PC
-- =========================================================
gen_index: for i in 0 to 1 generate
begin
    index_fetch(i) <= to_integer(unsigned(pc_in(i)(BTB_BITS+1 downto 2)));
end generate;

-- =========================================================
-- HIT / MISS
-- =========================================================
gen_hit: for i in 0 to 1 generate
begin
    hit(i) <= '1' when (btb_valid(index_fetch(i)) = '1' and
                        BTB(index_fetch(i)).tag = pc_in(i)) -- quantos comparadores?
              else '0';
end generate;

-- =========================================================
-- Prediction (IF)
-- =========================================================

gen_predict: for i in 0 to 1 generate
begin

    predict_taken(i) <= BTB(index_fetch(i)).pred(1)
                        when hit(i) = '1'
                        else '0';

    predict_pc(i) <= BTB(index_fetch(i)).target;

end generate;

-- =========================================================
-- Table update (EX)
-- =========================================================
process(clock, reset)
    variable idx : integer;
begin
    if reset = '1' then

        btb_valid <= (others => '0');

    elsif rising_edge(clock) then

        if Branch_inst(0) = '1' and (Branch_inst(1) = '0' or (Branch_inst(1) = '1' and taken_real(0) = '1')) then -- Branch_inst(1) = '0' then

            idx := to_integer(unsigned(pc_update(0)(BTB_BITS+1 downto 2)));

            btb_valid(idx)    <= '1';
            BTB(idx).tag    <= pc_update(0);
            BTB(idx).target <= target_real(0);

            case BTB(idx).pred is
                when "00" =>
                    if taken_real(0) = '1' then
                        BTB(idx).pred <= "01";
                    end if;

                when "01" =>
                    if taken_real(0) = '1' then
                        BTB(idx).pred <= "10";
                    else
                        BTB(idx).pred <= "00";
                    end if;

                when "10" =>
                    if taken_real(0) = '1' then
                        BTB(idx).pred <= "11";
                    else
                        BTB(idx).pred <= "01";
                    end if;

                when others =>
                    if taken_real(0) = '0' then
                        BTB(idx).pred <= "10";
                    end if;
            end case;

        elsif Branch_inst(0) = '0' and Branch_inst(1) = '1' then

            idx := to_integer(unsigned(pc_update(1)(BTB_BITS+1 downto 2)));

            btb_valid(idx)    <= '1';
            BTB(idx).tag    <= pc_update(1);
            BTB(idx).target <= target_real(1);

            case BTB(idx).pred is
                when "00" =>
                    if taken_real(1) = '1' then
                        BTB(idx).pred <= "01";
                    end if;

                when "01" =>
                    if taken_real(1) = '1' then
                        BTB(idx).pred <= "10";
                    else
                        BTB(idx).pred <= "00";
                    end if;

                when "10" =>
                    if taken_real(1) = '1' then
                        BTB(idx).pred <= "11";
                    else
                        BTB(idx).pred <= "01";
                    end if;

                when others =>
                    if taken_real(1) = '0' then
                        BTB(idx).pred <= "10";
                    end if;
            end case;
        elsif Branch_inst(0) = '1' and Branch_inst(1) = '1' and taken_real(0) = '0' then -- se o taken_real(0) for '0' a instrução Branch_inst(1) é valida, optamos por atualizar somente a tabela com a Branch_inst(1) para evitar atualizar as duas e ter uma True Dual Port Write

            idx := to_integer(unsigned(pc_update(1)(BTB_BITS+1 downto 2)));

            btb_valid(idx)  <= '1';
            BTB(idx).tag    <= pc_update(1);
            BTB(idx).target <= target_real(1);

            case BTB(idx).pred is
                when "00" =>
                    if taken_real(1) = '1' then
                        BTB(idx).pred <= "01";
                    end if;

                when "01" =>
                    if taken_real(1) = '1' then
                        BTB(idx).pred <= "10";
                    else
                        BTB(idx).pred <= "00";
                    end if;

                when "10" =>
                    if taken_real(1) = '1' then
                        BTB(idx).pred <= "11";
                    else
                        BTB(idx).pred <= "01";
                    end if;

                when others =>
                    if taken_real(1) = '0' then
                        BTB(idx).pred <= "10";
                    end if;
            end case;
        end if;
    end if;
end process;

end Behavioral;