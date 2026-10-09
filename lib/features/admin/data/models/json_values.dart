// Reading the numbers of a JSON object the admin functions return: a count
// or a rounded average may arrive as an int or as a double.

int intOf(Object? value) => (value! as num).toInt();

int? optionalIntOf(Object? value) => (value as num?)?.toInt();

double? optionalDoubleOf(Object? value) => (value as num?)?.toDouble();
