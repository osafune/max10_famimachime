-- ===================================================================
-- TITLE : Famima Chime - Sound Generator
--
--     DESIGN : S.OSAFUNE (J-7SYSTEM Works)
--     DATE   : 2014/10/20 -> 2014/10/20
--            : 2014/10/20 (FIXED)
--
-- ===================================================================
-- *******************************************************************
--   Copyright (C) 2014, J-7SYSTEM Works.  All rights Reserved.
--
-- * This module is a free sourcecode and there is NO WARRANTY.
-- * No restriction on use. You can use, modify and redistribute it
--   for personal, non-profit or commercial products UNDER YOUR
--   RESPONSIBILITY.
-- * Redistributions of source code must retain the above copyright
--   notice.
-- *******************************************************************

-- ファミマチャイムの１チャネル分の音源 
-- 矩形波出力＋エンベロープ出力 


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity famimachime_sg is
	generic(
		ENVELOPE_TC		: integer := 28000		-- エンベロープ時定数(一次遅れ系,t=0.5秒)
	);
	port(
		reset			: in  std_logic;		-- async reset
		clk				: in  std_logic;		-- system clock
		reg_div			: in  std_logic_vector(7 downto 0);		-- 分周値データ(0〜255) 
		reg_note		: in  std_logic;		-- ノートオン(1:発音開始 / 0:無効) 
		reg_write		: in  std_logic;		-- 1=レジスタ書き込み 

		timing_10us		: in  std_logic;		-- clock enable (10usタイミング,1パルス幅,1アクティブ) 
		timing_1ms		: in  std_logic;		-- clock enable (1msタイミング,1パルス幅,1アクティブ) 

		wave_out		: out std_logic_vector(15 downto 0)		-- 波形データ出力(符号付き16bit) 
	);
end famimachime_sg;

architecture RTL of famimachime_sg is
	signal divref_reg		: std_logic_vector(7 downto 0);
	signal note_reg			: std_logic;

	signal sqdivcount		: std_logic_vector(7 downto 0);
	signal sqwave_reg		: std_logic;

	constant ENVCOUNT_INIT	: std_logic_vector(14 downto 0) := CONV_std_logic_vector(ENVELOPE_TC,15);
	signal env_count_reg	: std_logic_vector(14 downto 0);
	signal env_cnext_sig	: std_logic_vector(14+9 downto 0);

	signal wave_pos_sig		: std_logic_vector(15 downto 0);
	signal wave_neg_sig		: std_logic_vector(15 downto 0);

begin

	-- 入力レジスタ 

	process (clk, reset) begin
		if (reset = '1') then
			divref_reg <= (others=>'0');
			note_reg   <= '0';

		elsif rising_edge(clk) then
			if (reg_write = '1') then
				divref_reg <= reg_div;
			end if;

			if (reg_write = '1' and reg_note = '1') then
				note_reg <= '1';
			elsif (timing_1ms = '1') then
				note_reg <= '0';
			end if;

		end if;
	end process;


	-- 矩形波生成 

	process (clk, reset) begin
		if (reset = '1') then
			sqdivcount <= (others=>'0');
			sqwave_reg <= '0';

		elsif rising_edge(clk) then
			if (timing_10us = '1') then
				if (sqdivcount = 0) then
					sqdivcount <= divref_reg;
					sqwave_reg <= not sqwave_reg;
				else
					sqdivcount <= sqdivcount - 1;
				end if;
			end if;

		end if;
	end process;


	-- エンベロープ生成 

	process (clk, reset)
		variable env_cnext_val	: std_logic_vector(env_count_reg'length + 9-1 downto 0);
	begin
		if (reset = '1') then
			env_count_reg <= (others=>'0');

		elsif rising_edge(clk) then
			if (timing_1ms = '1') then
				if (note_reg = '1') then
					env_count_reg <= ENVCOUNT_INIT;
				elsif (env_count_reg /= 0) then
					env_cnext_val := (env_count_reg & "000000000") - ("000000000" & env_count_reg);
					env_count_reg <= env_cnext_val(14+9 downto 0+9);	-- vonext = ((vo<<9) - vo)>>9
				end if;
			end if;

		end if;
	end process;


	-- 波形振幅変調と出力 

	wave_pos_sig <= '0' & env_count_reg;
	wave_neg_sig <= 0 - wave_pos_sig;

	wave_out <= wave_pos_sig when(sqwave_reg = '1') else wave_neg_sig;


end RTL;
