-- Возвращает текущее количество на складе товара с указанным @ProductId
CREATE FUNCTION [dbo].[GetCurProductAmount] (	
	@ProductId INT
)
returns INT 
as
begin
	declare @Amount INT
	set @Amount = isnull((select sum(Amount) from Arrival where ProductId = @ProductId), 0) - isnull((select sum(Amount) from Orders where ProductId = @ProductId), 0)
	return @Amount
end

GO

-- Возвращает таблицу со всеми датами в промежутке между @StartDate и @EndDate включительно
CREATE FUNCTION [dbo].[CalendarDates] (	
	@StartDat date,
	@EndDate date = null
)
returns @Dates table (
	[Дата] date,
	[День] varchar(20)
)
as
begin
	declare @TDate date = @StartDat
	set @EndDate = isnull(@EndDate, CAST(GETDATE() as date))
	while @TDate < @EndDate
	begin
		insert into @Dates ([Дата]) values (@TDate)
		set @TDate = dateadd(day, 1,@TDate) 
	end
	update @Dates set [День] = FORMAT(Дата, 'yyyy-MM-dd')
	return
end
GO
