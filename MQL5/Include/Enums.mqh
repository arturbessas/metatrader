enum periodicity_enum
{
	periodicity_1 = 0, //1 minuto
	periodicity_5 = 1, //5 minutos
	periodicity_10 = 2, //10 minutos 
	periodicity_15 = 3, //15 minutos 
	periodicity_30 = 4, //30 minutos 
	periodicity_60 =  5,//60 minutos
	periodicity_day =  6//1 dia
};

enum candle_type_enum
{
	candle_type_closed = 0, //Candles fechados
	candle_type_open = 1, //Candles abertos
};

enum break_type_enum
{
	break_type_prev = 0, //Rompimento do candle anterior
	break_type_ref = 1, //Rompimento do candle de referência
};

enum allowed_direction_enum
{
	allowed_direction_any = 0, //Comprado e vendido
	allowed_direction_buy = 1, //Apenas comprado
	allowed_direction_sell = 2, //Apenas vendido
};

enum trend_type_enum
{
	trend_type_trend = 0, //A favor da tendência
	trend_type_counter = 1, //Contra a tendência
};

enum break_direction_enum
{
	break_direction_any = 0, //Rompimento da máxima e/ou rompimento da mínima
	break_direction_min = 1, //Apenas rompimento da mínima
	break_direction_max = 2, //Apenas rompimento da máxima
};

enum bool_enum
{
	bool_false = 0, //Não
	bool_true = 1, //Sim
};

enum order_type_enum
{
	order_type_market = 0, //Mercado
	order_type_limit = 1, //Limite
};

enum dx_dy_enum
{
	none = 0, //Não
	using_dx = 1, //Usar distânciamento da máxima/mínima (DX)
	using_dy = 2, //Usar filtro por variação mínima do candle (DY)
};

enum price_type_enum
{
	price_type_close = 0, //Close
	price_type_open = 1, //Open
	price_type_high = 2, //High
	price_type_low = 3, //Low
};

enum operation_mode_enum
{
	operation_mode_any = 0, //Entradas e saídas
	operation_mode_entry = 1, //Apenas entradas
	operation_mode_exit = 2, //Apenas saídas
};

enum stop_type_enum
{
   stop_type_absolute = 0,   //Absoluto
   stop_type_percentual = 1, //Percentual
};

enum stop_reference_enum
{
   stop_reference_average = 0, //Preço médio
   stop_reference_entry = 1,   //Preço de entrada
};