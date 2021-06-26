USE [master]
USE [db]

CREATE TABLE [dbo].[Arrival](
	[ArrivalID] [int] IDENTITY(1,1) PRIMARY KEY,
	[DateInsert] [datetime] NULL,
	[Amount] [int] NOT NULL,
	[ProductId] [int] NULL,
)

CREATE TABLE [dbo].[Orders](
	[OrderID] [int] IDENTITY(1,1) PRIMARY KEY,
	[DateInsert] [datetime] NULL,
	[PersonID] [int] NULL,
	[Amount] [int] NOT NULL,
	[ProductId] [int] NULL,
	CHECK  ([Amount]>=0)
)

CREATE TABLE [dbo].[Person](
	[PersonID] [int] IDENTITY(1,1) PRIMARY KEY,
	[BirthDay] [date] NULL,
	[Cash] [int] NULL,
)

CREATE TABLE [dbo].[Product](
	[ProductId] [int] IDENTITY(1,1) PRIMARY KEY,
	[ProductName] [varchar](30) NULL,
	[Price] [int] NULL,
)

CREATE TABLE [dbo].[StoreState](
	[Дата] [date],
	[Amnt] [int],
	[ProductId] [int]
) ON [PRIMARY]



ALTER TABLE [dbo].[Arrival] ADD CONSTRAINT [FK_Arrival_ProductId] FOREIGN KEY([ProductId]) REFERENCES [dbo].[Product] ([ProductId])
ALTER TABLE [dbo].[Orders] ADD CONSTRAINT [FK_Orders_ProductId] FOREIGN KEY([ProductId]) REFERENCES [dbo].[Product] ([ProductId])
ALTER TABLE [dbo].[Orders] ADD CONSTRAINT [FK_PersonID_Orders] FOREIGN KEY([PersonID]) REFERENCES [dbo].[Person] ([PersonID])
ALTER TABLE [dbo].[StoreState] ADD  CONSTRAINT [FK_StoreState_ProductId] FOREIGN KEY([ProductId]) REFERENCES [dbo].[Product] ([ProductId])



INSERT [dbo].[Product] ([ProductName], [Price]) VALUES (N'Термостат жидкостной', 40)
INSERT [dbo].[Product] ([ProductName], [Price]) VALUES (N'Воронка Бюхнера', 100)
INSERT [dbo].[Product] ([ProductName], [Price]) VALUES (N'Воронка делительная', 200)
INSERT [dbo].[Product] ([ProductName], [Price]) VALUES (N'Виалы', 100)
INSERT [dbo].[Product] ([ProductName], [Price]) VALUES (N'Бюретка', 100)
INSERT [dbo].[Product] ([ProductName], [Price]) VALUES (N'колба коническая', 300)
INSERT [dbo].[Product] ([ProductName], [Price]) VALUES (N'Колба круглодонная', 500)
INSERT [dbo].[Product] ([ProductName], [Price]) VALUES (N'Холодильники ХШ 1-400-29', 20)
INSERT [dbo].[Product] ([ProductName], [Price]) VALUES (N'Холодильники ХШ 1-200-14', 20)

INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-02-03T06:12:00.000' AS DateTime), 10, 2)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-02-02T06:12:00.000' AS DateTime), 20, 1)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-01-02T03:12:00.000' AS DateTime), 50, 1)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-05-21T00:00:00.000' AS DateTime), 100, 2)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-05-21T00:00:00.000' AS DateTime), 100, 3)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-05-21T00:00:00.000' AS DateTime), 50, 4)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-05-21T00:00:00.000' AS DateTime), 125, 5)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-05-21T00:00:00.000' AS DateTime), 10, 6)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-05-21T00:00:00.000' AS DateTime), 8, 7)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-05-21T00:00:00.000' AS DateTime), 20, 8)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-05-21T00:00:00.000' AS DateTime), 20, 9)
INSERT [dbo].[Arrival] ([DateInsert], [Amount], [ProductId]) VALUES (CAST(N'2021-05-22T21:09:26.310' AS DateTime), 1337, 3)

INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'2020-01-02' AS Date), 25)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'2020-02-03' AS Date), 0)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'2002-04-02' AS Date), 0)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'2002-01-01' AS Date), 0)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'2002-01-01' AS Date), 25)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'2002-01-01' AS Date), 125)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'2002-01-01' AS Date), 0)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'2002-01-01' AS Date), 0)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'1999-05-05' AS Date), 890)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'1999-05-05' AS Date), 925)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'1999-02-05' AS Date), 205)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'1989-11-05' AS Date), 100)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'1979-12-05' AS Date), 75)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'1979-12-05' AS Date), 99)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'1960-12-05' AS Date), 950)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'1960-12-25' AS Date), 66)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'1965-11-25' AS Date), 33)
INSERT [dbo].[Person] ([BirthDay], [Cash]) VALUES (CAST(N'1965-11-30' AS Date), 62)

INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-02-03T07:12:00.000' AS DateTime), 2, 5, 2)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-02-04T10:10:00.000' AS DateTime), 2, 2, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-02-05T09:08:00.000' AS DateTime), 1, 10, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T14:11:17.560' AS DateTime), 8, 3, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T14:24:18.363' AS DateTime), 16, 3, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T14:24:18.363' AS DateTime), 17, 3, 2)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T14:24:18.370' AS DateTime), 10, 3, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T14:24:18.370' AS DateTime), 10, 3, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T14:24:18.370' AS DateTime), 10, 3, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T14:24:18.373' AS DateTime), 1, 3, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T14:24:18.373' AS DateTime), 2, 3, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:02:52.070' AS DateTime), 15, 1, 3)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:03:12.003' AS DateTime), 7, 2, 4)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:04:03.253' AS DateTime), 12, 5, 4)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:04:18.607' AS DateTime), 14, 5, 3)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:04:25.013' AS DateTime), 4, 5, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:04:33.233' AS DateTime), 2, 5, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:04:46.330' AS DateTime), 2, 1, 3)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:04:54.070' AS DateTime), 16, 10, 5)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:04:58.280' AS DateTime), 3, 10, 5)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:05:05.087' AS DateTime), 3, 10, 2)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:05:22.380' AS DateTime), 9, 1, 2)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:05:46.580' AS DateTime), 15, 2, 2)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:05:54.760' AS DateTime), 18, 5, 5)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:06:48.627' AS DateTime), 6, 5, 5)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:06:57.890' AS DateTime), 6, 5, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:07:13.490' AS DateTime), 8, 11, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:07:22.573' AS DateTime), 11, 11, 2)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:07:26.133' AS DateTime), 9, 11, 1)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T15:07:29.850' AS DateTime), 12, 11, 3)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T21:11:12.947' AS DateTime), 1, 11, 3)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T21:14:31.293' AS DateTime), 1, 1, 2)
INSERT [dbo].[Orders] ([DateInsert], [PersonID], [Amount], [ProductId]) VALUES (CAST(N'2021-05-23T21:21:03.307' AS DateTime), 10, 1, 3)





