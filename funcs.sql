-- ���������� ������� ���������� �� ������ ������ � ��������� @ProductId
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

-- ���������� ������� �� ����� ������ � ���������� ����� @StartDate � @EndDate ������������
CREATE FUNCTION [dbo].[CalendarDates] (	
	@StartDat date,
	@EndDate date = null
)
returns @Dates table (
	[����] date,
	[����] varchar(20)
)
as
begin
	declare @TDate date = @StartDat
	set @EndDate = isnull(@EndDate, CAST(GETDATE() as date))
	while @TDate < @EndDate
	begin
		insert into @Dates ([����]) values (@TDate)
		set @TDate = dateadd(day, 1,@TDate) 
	end
	update @Dates set [����] = FORMAT(����, 'yyyy-MM-dd')
	return
end
GO
