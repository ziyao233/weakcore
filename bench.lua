local coverify		= require "coverify";
local Vweakcore		= require "Vweakcore";

local math		= require "math";
local os		= require "os";
local io		= require "io";
local string		= require "string";

local weakcore = Vweakcore.new();

if os.getenv("DUMP") then
	weakcore:trace(true);
end

local maxcycle = os.getenv("MAXCYCLE") or math.maxinteger;

local bench = coverify.Bench(weakcore);

-- 16KiB
local ram = { };
for i = 1, 4096 do
	ram[i] = 0;
end

if arg[1] then
	local bin = assert(io.open(arg[1], 'r')):read('a');
	local cells = #bin // 4;

	for i = 1, cells do
		local off = (i - 1) * 4 + 1;
		ram[i] = (bin:sub(off + 3, off + 3):byte() << 24)	|
			 (bin:sub(off + 2, off + 2):byte() << 16)	|
			 (bin:sub(off + 1, off + 1):byte() << 8)	|
			 (bin:sub(off, off):byte());
	end

	if cells * 4 ~= #bin then
		local off = cells * 4 + 1;
		cells = cells + 1;

		ram[cells] = (bin:sub(off + 3, off + 3):byte() or 0) << 24 |
			     (bin:sub(off + 2, off + 2):byte() or 0) << 16 |
			     (bin:sub(off + 1, off + 1):byte() or 0) << 8  |
			     (bin:sub(off, off):byte() or 0);

		ram[cells + 1] = bin:sub(off + 3, off + 3) or 0;
	end
end

local printBusOperation = os.getenv("DEBUG_BUS") and
	function(wr, addr, data)
		data = wr and data or ram[addr / 4 + 1];
		print(("BUSOP: %s 0x%08x, data = 0x%08x"):
		      format(wr and "write" or "read", addr, data));
	end or
	function() end;

bench:register(function(bench)
	bench:set("bus_ack", 0);

	while true do
		bench:waitClk("preposedge");
		bench:set("bus_ack", 0);

		if bench:get("bus_req") == 1 then
			local addr = bench:get("bus_addr");
			local data = bench:get("bus_out");
			local wr = bench:get("bus_wr") == 1;

			printBusOperation(wr, addr, data);

			bench:waitClk("posedge");

			if wr then
				if addr == 0x80000000 then
					print(data);
				elseif addr == 0x80000004 then
					io.write(string.char((data & 0xff)));
				elseif addr == 0x80000008 then
					bench:pass();
				else
					ram[addr / 4 + 1] = data;
				end
			else
				bench:set("bus_in", ram[addr / 4 + 1]);
			end

			bench:set("bus_ack", 1);
			bench:waitClk("posedge");
		end
	end
end);

bench:register(function(bench)
	for i = 1, maxcycle do
		bench:waitClk("posedge");
	end
	bench:pass();
end);
bench:run("clk", "rst");
