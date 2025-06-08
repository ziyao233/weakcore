local coroutine		= require "coroutine";

local benchMeta = {};
benchMeta.__index = benchMeta;

benchMeta.set = function(self, key, value)
	self.instance:set(key, value);
end

benchMeta.get = function(self, key)
	return self.instance:get(key);
end

local acceptable = {
			["posedge"] = true, ["preposedge"] = true,
			["negedge"] = true
		   };
benchMeta.waitClk = function(self, edge)
	if not acceptable[edge] then
		error(("Invalid edge %s"):format(edge));
	end

	table.insert(self[edge], (coroutine.running()));
	coroutine.yield();
end

benchMeta.pass = function(self)
	self.passed = true;
end

benchMeta.run = function(self, clkName, rstName, rstAssert, rstDelay)
	assert(not self.started, "The testbench is already started");

	local instance = self.instance;
	local resume = coroutine.resume;

	rstAssert	= rstAssert or 0;
	rstDelay	= rstDelay or 1;

	if rstName then
		instance:set(rstName, rstAssert);

		for i = 1, rstDelay do
			instance:set(clkName, 0);
			instance:eval();
			instance:set(clkName, 1);
			instance:eval();
		end

		instance:set(rstName, rstAssert == 1 and 0 or 1);
	end

	self.started = true;

	instance:set(clkName, 0);
	instance:eval();

	while not self.passed do
		local preposedge = self.preposedge;
		self.preposedge = {};
		for _, co in pairs(preposedge) do
			assert(resume(co));
		end
		instance:eval();

		instance:set("clk", 1);
		instance:eval();

		local posedge = self.posedge;
		self.posedge = {};
		for _, co in pairs(posedge) do
			assert(resume(co));
		end

		instance:eval();

		instance:set("clk", 0);
		instance:eval();

		local negedge = self.negedge;
		self.negedge = {};
		for _, co in pairs(negedge) do
			assert(resume(co));
		end
		instance:eval();
	end
end

benchMeta.register = function(self, func)
	local co = coroutine.create(func);
	assert(coroutine.resume(co, self));
end

local function
Bench(instance)
	local bench = {
			instance	= instance,
			preposedge	= {},
			posedge		= {},
			negedge		= {},
		      };
	return setmetatable(bench, benchMeta);
end

return {
	Bench		= Bench,
       };
