class_name CanonicalContent
extends RefCounted


static func stringify(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return JSON.stringify(float(value))
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(String(value))
		TYPE_ARRAY:
			var items := PackedStringArray()
			for item: Variant in value:
				items.append(stringify(item))
			return "[" + ",".join(items) + "]"
		TYPE_DICTIONARY:
			var keys: Array[String] = []
			for key: Variant in (value as Dictionary).keys():
				keys.append(String(key))
			keys.sort()
			var members := PackedStringArray()
			for key: String in keys:
				members.append(JSON.stringify(key) + ":" + stringify((value as Dictionary)[key]))
			return "{" + ",".join(members) + "}"
		_:
			return ""


static func sha256(value: Variant) -> String:
	return CanonicalBytes.sha256_hex(stringify(value).to_utf8_buffer())
