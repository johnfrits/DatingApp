USE [M01_MODULES]
GO
/****** Object:  StoredProcedure [dbo].[sp_api_CreateDefaultGLAccountCompany]    Script Date: 29/10/2019 8:59:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  Indulis Misins,Lbije
-- Create date: 28.07.2016
-- Update date: 19.03.2019
-- Description: Populates DB with default GL Account and Classifier data for company
-- Update: 2019-06-07 LBije Make default RGS to RGSCode3
-- Update: 2019-06-10 LBije Added upate for TGLAccountClass fk_parent_id 
-- =============================================
ALTER PROCEDURE [dbo].[sp_api_CreateDefaultGLAccountCompany]
	@CompanyId int
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Id int
	DECLARE @SoftwareId int
	DECLARE @UseBookkeeping bit = 0;
	DECLARE @OrgId int;

	DECLARE @ClassId int, @ClassDefaultId int
	SET @ClassId = IDENT_CURRENT('dbo.[TGLAccountClass]')
	DECLARE @GLAccountId int, @GLAccountDefaultId int
	SET @GLAccountId = IDENT_CURRENT('dbo.[TGLAccount]')
	DECLARE @countryId int;
	SELECT	@countryId = fk_country_id, @SoftwareId = fk_software_id, @OrgId = fk_organisation_id FROM gateway.TCompany WHERE Id = @CompanyId;

	SELECT TOP(1) @UseBookkeeping = UseBookkeeping FROM MFO_GLOBAL.DBO.TProfileOrganization WHERE Id = @OrgId;

	DECLARE @LegalForm varchar(20) = ''
	SELECT @LegalForm = l.Code FROM gateway.TCompany c
	JOIN MFO_GLOBAL.dbo.TLegalForm l on c.fk_legalform_id = l.Id
	 WHERE c.Id = @CompanyId 

	--Check if there is country specific TGLAccountScheme EXISTS. If there is then use them else use default.
	DECLARE @hasScheme INT;
	SELECT @hasScheme = COUNT(Id) from [MFO_DEFAULT].[dbo].[TDefaultGLAccountScheme] WHERE fk_country_id = @countryId;

	INSERT	[dbo].[TGLAccountScheme] ([fk_company_id], [Code], [Description], [IsMain], [CreDate], [CreTime], [CreUsr]) 
	SELECT	TOP (1) @CompanyId, [Code], [Description], [IsMain], GETDATE(), CAST( GETDATE() as time), 'System'
	FROM	[MFO_DEFAULT].[dbo].[TDefaultGLAccountScheme]
	WHERE	((@hasScheme > 0 AND fk_country_id = @countryId) OR (@hasScheme = 0 AND fk_country_id IS NULL));

	SET @Id = @@IDENTITY;

	--Get Id value of first [TDefaultGLAccountClass] for company country
	SET @ClassDefaultId = ISNULL((SELECT MIN(Id) FROM [MFO_DEFAULT].[dbo].[TDefaultGLAccountClass] WHERE fk_country_id = @countryId
	AND  (((@LegalForm is not null AND @LegalForm <> '' AND @LegalForm = LegalForm) OR (@LegalForm is null OR @LegalForm = '')))), 0);

	IF @ClassDefaultId > 0
	BEGIN
		INSERT	[dbo].[TGLAccountClass] ([fk_company_id], [Code] , [SortCode], [DescriptionCode],[BSOrProfitLoss],[fk_GLAccountScheme_id],
				[fk_parent_id], [IsDefault],[GLaccountType],[IsMainType],[Category], [TypeOfBusiness],[SubCategory], [CreDate], [CreTime], [CreUsr])
		SELECT	@CompanyId, [Code] ,[SortCode], [DescriptionCode],[BSOrProfitLoss],@Id,
				[fk_parent_id] + @ClassId - @ClassDefaultId + 1, [IsDefault],[GLaccountType],[IsMainType],[Category], [TypeOfBusiness],[SubCategory], GETDATE(), CAST( GETDATE() as time), 'System'
		FROM	[MFO_DEFAULT].[dbo].[TDefaultGLAccountClass]
		WHERE	fk_country_id = @countryId  AND ((@LegalForm is not null AND @LegalForm <> '' AND LegalForm = @LegalForm) OR 
				((@LegalForm is null OR @LegalForm = '') AND LegalForm is null))

		UPDATE gc
			set gc.fk_parent_id = p.Id
		from TGLAccountClass gc
		join gateway.TCompany c on gc.fk_company_id = c.Id
		left join MFO_GLOBAL.dbo.TLegalForm l on c.fk_legalform_id = l.Id
		join [MFO_DEFAULT].[dbo].[TDefaultGLAccountClass] d1 on gc.Code = d1.Code
		join [MFO_DEFAULT].[dbo].[TDefaultGLAccountClass] d2 on d2.Id = d1.fk_parent_id
		join TGLAccountClass p on d2.Code = p.Code
		where gc.fk_company_id = @CompanyId and (d1.LegalForm = l.Code OR (d1.LegalForm is null AND l.Code is null))
		and d1.fk_parent_id is not null and p.fk_company_id = @CompanyId

		INSERT	[dbo].[TTranslation] ([fk_company_id], [fk_language_id], [Code], [Description], [IsBuiltIn], [CreDate], [CreTime], [CreUsr]) 
		SELECT	@CompanyId, [fk_language_id], [Code], [Description], [IsBuiltIn], GETDATE(), CAST( GETDATE() as time), 'System'
		FROM	[MFO_DEFAULT].[dbo].[TDefaultTranslation]
		WHERE	[fk_country_id] = @countryId AND [Code] IN (SELECT DescriptionCode FROM [dbo].[TGLAccountClass] WHERE fk_company_id = @CompanyId)
	END

	--Get Id value of first [TDefaultGLAccount] for company country
	SET @GLAccountDefaultId = ISNULL((SELECT MIN(Id) FROM [MFO_DEFAULT].[dbo].[TDefaultGLAccount] WHERE fk_country_id = @countryId
	AND  (((@LegalForm is not null AND @LegalForm <> '' AND @LegalForm = LegalForm) OR (@LegalForm is null OR @LegalForm = '')))), 0);

	IF @GLAccountDefaultId > 0
	BEGIN
		INSERT	[dbo].[TGLAccount] ([fk_company_id], [fk_glaccountclassification_id], [Code], [DescriptionCode], [SearchCode], [Type], [BSProfitLoss], 
				[IsDebit], [IsBlocked], [IsCompress], [IsMatching], [VatReturnType], [IsExcludeOnVat], [IsChangeNonDedVatPerc], 
				[ChangeNonDedVatPerc], [fk_nondedvatGLAccount_id], [PrivateUsePerc], 
				[fk_PrivateUseGLAccount_id], [ExpenseNonDedPerc], 
				[CostCentreAnalyse], [CostUnitAnalyse], [fk_costcentre_id], [fk_costunit_id], [fk_vatcode_id], [RGSCode], [RGSCode2], [RGSCode3], [RGSLevel], [IsDefault], [CreDate], [CreTime], [CreUsr],
				SortCode) 
		SELECT	@CompanyId, C.Id, GL.[Code], GL.[DescriptionCode], [SearchCode], [Type], [BSProfitLoss], 
				[IsDebit], [IsBlocked], [IsCompress], [IsMatching], [VatReturnType], [IsExcludeOnVat], [IsChangeNonDedVatPerc], 
				GL.[ChangeNonDedVatPerc], GL.[fk_nondedvatGLAccount_id] + @GLAccountId - @GLAccountDefaultId + 1, [PrivateUsePerc], 
				[fk_PrivateUseGLAccount_id] + @GLAccountId - @GLAccountDefaultId + 1, [ExpenseNonDedPerc], 
				[CostCentreAnalyse], [CostUnitAnalyse], [fk_costcentre_id], [fk_costunit_id], VT.[id], [RGSCode], [RGSCode2], [RGSCode3], [RGSLevel], GL.[IsDefault], GETDATE(), CAST( GETDATE() as time), 'System',
				GL.SortCode
		FROM	[MFO_DEFAULT].[dbo].[TDefaultGLAccount] GL
		LEFT JOIN TVatCode VT ON VT.Code = GL.vatcode_code
		LEFT JOIN MFO_DEFAULT.dbo.TDefaultGLAccountClass GC on GL.fk_glaccountclassification_id = GC.Id AND GL.LegalForm = GC.LegalForm
		LEFT JOIN TGLAccountClass C ON GC.Code = C.Code AND  C.fk_company_id = @CompanyId
        INNER JOIN MFO_DEFAULT.dbo.TDefaultTranslation TDT on TDT.Code = GL.DescriptionCode
		WHERE	GL.fk_country_id = @countryId  AND  GL.UseBookkeeping = @UseBookkeeping AND TDT.UseBookkeeping = @UseBookkeeping AND 
		 ((@LegalForm is not null AND @LegalForm <> '' AND @LegalForm = GL.LegalForm) OR ((@LegalForm is null OR @LegalForm = '') AND GL.LegalForm IS NULL)) 

		INSERT	[dbo].[TTranslation] ([fk_company_id], [fk_language_id], [Code], [Description], [IsBuiltIn], [CreDate], [CreTime], [CreUsr]) 
		SELECT	@CompanyId, [fk_language_id], [Code], [Description], [IsBuiltIn], GETDATE(), CAST( GETDATE() as time), 'System'
		FROM	[MFO_DEFAULT].[dbo].[TDefaultTranslation]
		WHERE	[fk_country_id] = @countryId AND UseBookkeeping = @UseBookkeeping AND [Code] IN (SELECT DescriptionCode FROM [dbo].[TGLAccount] WHERE fk_company_id = @CompanyId)
	END

	IF @SoftwareId = 1 AND @LegalForm <> ''
		BEGIN
			UPDATE v
				set v.fk_glaccountvatclaim_id = a.Id
			FROM TVATCode v
			JOIN [MFO_DEFAULT].dbo.[TDefaultVATCode] d on d.Code = v.Code and d.TransactionType = v.TransactionType
			AND d.fk_vatcodetype_id = v.fk_vatcodetype_id
			JOIN [MFO_DEFAULT].dbo.[TDefaultGLAccount] g on d.fk_glaccountvatclaim_id = g.Id
			JOIN TGLAccount a on g.Code = a.Code and g.Type = a.Type
			WHERE v.fk_company_id = @CompanyId and d.LegalForm = @LegalForm and a.fk_company_id = @CompanyId and g.LegalForm = @LegalForm
			AND g.fk_country_id = @countryId

			UPDATE v
				set v.fk_glaccountvatpay_id = a.Id
			FROM TVATCode v
			JOIN [MFO_DEFAULT].dbo.[TDefaultVATCode] d on d.Code = v.Code and d.TransactionType = v.TransactionType
			AND d.fk_vatcodetype_id = v.fk_vatcodetype_id
			JOIN [MFO_DEFAULT].dbo.[TDefaultGLAccount] g on d.fk_glaccountvatpay_id = g.Id
			JOIN TGLAccount a on g.Code = a.Code and g.Type = a.Type
			WHERE v.fk_company_id = @CompanyId and d.LegalForm = @LegalForm and a.fk_company_id = @CompanyId and g.LegalForm = @LegalForm
			AND g.fk_country_id = @countryId
			
		END
	ELSE
		BEGIN
			--Set in TVatCode values for columns fk_glaccountvatclaim_id and fk_glaccountvatpay_id
			DECLARE @VatclaimId int, @VatpayId int;
			IF @countryId = 1 -- BE
			BEGIN
				SELECT @VatclaimId = Id FROM TGLAccount WHERE fk_company_id = @CompanyId AND Code = '411000';
				SELECT @VatpayId = Id FROM TGLAccount WHERE fk_company_id = @CompanyId AND Code = '451000';
			END
			ELSE IF @countryId = 2 --NL
			BEGIN
				SELECT @VatclaimId = Id FROM TGLAccount WHERE fk_company_id = @CompanyId AND Code = '1540';
				SELECT @VatpayId = Id FROM TGLAccount WHERE fk_company_id = @CompanyId AND Code = '1500';
			END
			ELSE IF @countryId = 97 --IR
			BEGIN
				SELECT @VatclaimId = Id FROM TGLAccount WHERE fk_company_id = @CompanyId AND Code = '451';
				SELECT @VatpayId = Id FROM TGLAccount WHERE fk_company_id = @CompanyId AND Code = '411';
			END
			ELSE IF @countryId = 127 --LV
			BEGIN
				SELECT @VatclaimId = Id FROM TGLAccount WHERE fk_company_id = @CompanyId AND Code = '411000';
				SELECT @VatpayId = Id FROM TGLAccount WHERE fk_company_id = @CompanyId AND Code = '451000';
			END
			ELSE IF @countryId = 167 --PH
			BEGIN
				SELECT @VatclaimId = Id FROM TGLAccount WHERE fk_company_id = @CompanyId AND Code = '1501';
				SELECT @VatpayId = Id FROM TGLAccount WHERE fk_company_id = @CompanyId AND Code = '2115';
			END

			UPDATE TVATCode
			SET fk_glaccountvatclaim_id = @VatclaimId
			WHERE fk_company_id = @CompanyId AND fk_glaccountvatclaim_id IS NULL;

			UPDATE TVATCode
			SET fk_glaccountvatpay_id = @VatpayId
			WHERE fk_company_id = @CompanyId AND fk_glaccountvatpay_id IS NULL;
		END
	DECLARE @ctr int = -1

	SELECT 
		@ctr = COUNT(Id)
	FROM TVATCode
	WHERE fk_company_id = @CompanyId AND (fk_glaccountpurchase_id IS NOT NULL OR fk_glaccountsales_id IS NOT NULL)

	IF @ctr < 1 AND @SoftwareId = 1
	BEGIN
		DECLARE @Cnt int
		DECLARE @VATId int
		DECLARE @VATCode nchar(10)
		DECLARE @VATTranType int

		DECLARE vatCodeCur CURSOR FOR 
		SELECT Id, Code, TransactionType	
		FROM TVATCode
		WHERE fk_company_id = @CompanyId
		OPEN vatCodeCur FETCH NEXT FROM vatCodeCur INTO @VATId, @VATCode, @VATTranType
		
		WHILE @@FETCH_STATUS = 0
			BEGIN
				DECLARE @GLCode nvarchar(20) = ''
				SET @Cnt = 0

				SELECT @Cnt = count(*)
				FROM [MFO_DEFAULT].[dbo].[TDefaultVATCode]
				WHERE Code = @VATCode 
 					AND TransactionType = @VATTranType
					AND fk_software_id = @SoftwareId
					AND  (((@LegalForm is not null AND @LegalForm <> '' AND @LegalForm = LegalForm) OR (@LegalForm is null OR @LegalForm = '')))

				IF (@Cnt > 0)
					BEGIN
						
						DECLARE @GLAcctId int = -1
						SELECT @GLCode = GLAccountCodePurchase from [MFO_DEFAULT].[dbo].[TDefaultVATCode]
						WHERE Code = @VATCode and TransactionType = @VATTranType and fk_software_id = @SoftwareId AND 
						 (((@LegalForm is not null AND @LegalForm <> '' AND @LegalForm = LegalForm AND fk_country_id = @countryId) OR (@LegalForm is null OR @LegalForm = '')))

						IF (@GLCode is not null AND @GLCode <> '')
							BEGIN
								SELECT
									@GLAcctId = Id
								FROM TGLAccount
								WHERE fk_company_id = @CompanyId AND Code = @GLCode

								IF @GLAcctId > 0
								BEGIN
									UPDATE TVATCode
									SET fk_glaccountpurchase_id = @GLAcctId
									WHERE fk_company_id = @CompanyId AND Id = @VATId
								END
							END

						SET @GLCode = ''
						SET @GLAcctId = -1
						SELECT @GLCode = GLAccountCodeSales from [MFO_DEFAULT].[dbo].[TDefaultVATCode]
						WHERE Code = @VATCode and TransactionType = @VATTranType and fk_software_id = @SoftwareId AND 
						 (((@LegalForm is not null AND @LegalForm <> '' AND @LegalForm = LegalForm AND fk_country_id = @countryId) OR (@LegalForm is null OR @LegalForm = '')))

						IF (@GLCode is not null AND @GLCode <> '')
							BEGIN
								SELECT
									@GLAcctId = Id
								FROM TGLAccount
								WHERE fk_company_id = @CompanyId AND Code = @GLCode

								IF @GLAcctId > 0
								BEGIN
									UPDATE TVATCode
									SET fk_glaccountsales_id = @GLAcctId
									WHERE fk_company_id = @CompanyId AND Id = @VATId
								END
							END

					END

				FETCH NEXT FROM vatCodeCur INTO @VATId, @VATCode, @VATTranType
			END
			
			CLOSE vatCodeCur
			DEALLOCATE vatCodeCur
	END

END
