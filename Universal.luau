local Universal = {}

function Universal.GetStates(self)
	return self.Data.States
end

function Universal.TryAttack(self, targetRoot: BasePart): boolean
	return self.Data.TryAttack(self, targetRoot)
end

return Universal