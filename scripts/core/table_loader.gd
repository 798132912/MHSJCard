extends RefCounted
class_name TableLoader

static func load_csv(path: String) -> Array[Dictionary]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取表格: %s" % path)
		return []

	var rows: Array[PackedStringArray] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 0:
			continue
		if row.size() == 1 and row[0].strip_edges() == "":
			continue
		rows.append(row)

	if rows.is_empty():
		return []

	var headers := rows[0]
	var result: Array[Dictionary] = []
	for i in range(1, rows.size()):
		var source := rows[i]
		var item := {}
		for j in range(headers.size()):
			var key := headers[j]
			item[key] = source[j] if j < source.size() else ""
		result.append(item)

	return result
