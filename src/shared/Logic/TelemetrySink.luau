--!strict
--[[
	The durable playtest sink (Prompt 0, Gate G1): every telemetry call is also kept as a record in a
	DataStore, one key per player per server (`<placeId>/<serverId>/<userId>`), so a closed playtest
	can be read back after its servers have shut down. Pure: Services/TelemetryService owns the
	buffers and the store; this module holds the record, buffer, cap and CSV rules.

	A buffer collects records until a flush. A flush merges what is pending onto what the key
	already holds; a failed flush leaves the buffer as it was. A key never holds more than `max`
	records: the last place is kept for one `sink_overflow` record whose value counts the dropped ones.
]]

local TelemetrySink = {}

export type Record = {
	t: number, -- seconds since the player joined this server
	name: string,
	value: number,
	f1: string?,
	f2: string?,
	f3: string?,
}

export type Buffer = {
	pending: { Record },
	dropped: number, -- records dropped past the cap so far (this key)
}

TelemetrySink.Overflow = "sink_overflow"

function TelemetrySink.key(placeId: number, serverId: string, userId: number): string
	return `{placeId}/{serverId}/{userId}`
end

function TelemetrySink.prefix(placeId: number, serverId: string?): string
	return if serverId then `{placeId}/{serverId}/` else `{placeId}/`
end

function TelemetrySink.newBuffer(): Buffer
	return { pending = {}, dropped = 0 }
end

function TelemetrySink.record(t: number, name: string, value: number, fields: { string | false }?): Record
	local f = fields or {}
	local function slot(i: number): string?
		local v = f[i]
		return if type(v) == "string" then v else nil
	end
	return {
		t = math.floor(t * 100 + 0.5) / 100,
		name = name,
		value = value,
		f1 = slot(1),
		f2 = slot(2),
		f3 = slot(3),
	}
end

function TelemetrySink.add(buffer: Buffer, record: Record)
	table.insert(buffer.pending, record)
end

--[[
	What the key holds after a flush: `stored` (the key's current value, or nil) with `pending`
	appended, at most `max` records. A trailing overflow record is replaced by one counting every
	drop so far (`dropped` from earlier flushes plus this one's). Returns the new value and the new
	total of dropped records.
]]
function TelemetrySink.merge(
	stored: { Record }?,
	pending: { Record },
	dropped: number,
	max: number
): ({ Record }, number)
	local out: { Record } = {}
	local base: { Record } = stored or {}
	for _, record in base do
		if record.name ~= TelemetrySink.Overflow then
			table.insert(out, record)
		end
	end
	local room = math.max(max - 1, 0) -- the last place is the overflow record's
	local total = dropped
	for _, record in pending do
		if #out < room then
			table.insert(out, record)
		else
			total += 1
		end
	end
	if total > 0 then
		local last = pending[#pending]
		table.insert(out, {
			t = if last then last.t else 0,
			name = TelemetrySink.Overflow,
			value = total,
		})
	end
	return out, total
end

-- After a successful flush of the first `count` pending records: drop them, keep any added since.
function TelemetrySink.flushed(buffer: Buffer, count: number, dropped: number)
	local rest: { Record } = {}
	for i = count + 1, #buffer.pending do
		table.insert(rest, buffer.pending[i])
	end
	buffer.pending = rest
	buffer.dropped = dropped
end

function TelemetrySink.csvHeader(): string
	return "key,t,name,value,f1,f2,f3"
end

function TelemetrySink.csv(key: string, records: { Record }): { string }
	local rows: { string } = {}
	for _, r in records do
		table.insert(
			rows,
			table.concat(
				{ key, tostring(r.t), r.name, tostring(r.value), r.f1 or "", r.f2 or "", r.f3 or "" },
				","
			)
		)
	end
	return rows
end

return table.freeze(TelemetrySink)
