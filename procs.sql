CREATE PROCEDURE [dbo].[AddPerson]
@BirthDay date,
@Cash INT,
@Message VARCHAR(100) output
as
Insert into Person (BirthDay, Cash) values (@BirthDay, @Cash)
set @Message = '���������� ������� ��������!'
return

GO

CREATE PROCEDURE [dbo].[CreateOrder]
@PersonID INT,
@Amount INT,
@ProductId INT,
@Success bit output,
@Message varchar(100) output
as
set @Message = ''
declare @Cost INT = (select Price from Product where ProductId = @ProductId)
declare @CurCash INT = (select Cash from Person where PersonID = @PersonID)
declare @CurAmount INT = dbo.GetCurProductAmount(@ProductId)
set @Success = 0
Begin transaction
if(@Amount <= @CurAmount)
	Insert into Orders (Dateinsert, PersonID, Amount, ProductId) values (GETDATE(), @PersonID, @Amount, @ProductId)
else 
	Begin
	set @Message = '����� �� ������ �����������!'
	Rollback transaction 
	return
	End
if(@Amount * @Cost <= @CurCash)
	UPDATE Person set Cash = Cash - @Amount * @Cost where PersonID = @PersonID
else 
	Begin
	set @Message = '������������ ������� � ����������!'
	Rollback transaction 
	return
	End
Commit transaction
set @Message = '�������� ��������� �������!'
set @Success = 1
return


GO

-- ��������� ��� ���������� ���������� ��������� ������
CREATE PROCEDURE [dbo].[UpdateStore]
as
Begin
declare @CurDate as date =  CAST(GETDATE() as date)
declare @UpdateFrom as date = CAST(DATEADD(DD, -5, @CurDate) as date)
DELETE FROM StoreState where (���� >= @UpdateFrom)

insert into StoreState ([ProductId], [����], [Amnt]) 
select ProductId, ����, isnull(sum(Amount), 0) as Amnt from CalendarDates (@UpdateFrom, @CurDate)
left join (
select DateInsert, Amount, ProductId from Arrival 
union
select DateInsert, -Amount, ProductId from Orders
) as Operations
on ���� > DateInsert
where ProductId is not null
group by ����, ProductId;
end