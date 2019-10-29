USE [M01_MODULES]
GO
/****** Object:  StoredProcedure [dbo].[sp_api_CreateDefaultCompany]    Script Date: 29/10/2019 4:19:40 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  Indulis Misins
-- Create date: 28.07.2016
-- Description: Populates DB with default data for company
-- TworkflowTemplate, TWorkflowTemplateContent, TTitle, TSequence, TLayout, TLayoutView
-- If software = MFO then insert - VatCode, PaymentCondition, Translation
-- 20190809 LBije Added countryId in condition for inserting vat codes if legalform is not null
-- =============================================
ALTER PROCEDURE [dbo].[sp_api_CreateDefaultCompany]
	@CompanyId int,
	@IsWorkflow bit,
	@IsInvoicing bit,
	@IsInvoicingTemplate bit,
	@IsOrder bit,
	@IsOrderTemplate bit
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Id int
	DECLARE @OrgId int = -1;
	DECLARE @UseBookkeeping bit = 0;

	SELECT TOP(1) @OrgId = fk_organisation_id FROM MFO_GLOBAL.DBO.TCompany WHERE Id = @CompanyId;
	SELECT TOP(1) @UseBookkeeping = UseBookkeeping FROM MFO_GLOBAL.DBO.TProfileOrganization WHERE Id = @OrgId;

	IF(NOT EXISTS(SELECT top 1 Id from TWorkflowTemplate where fk_company_id = @CompanyId) AND @IsWorkflow = 1)
	BEGIN
		IF (@OrgId != -1) AND EXISTS(SELECT fk_organization_id FROM MFO_DEFAULT.DBO.TDefaultWorkflowTemplate WHERE fk_organization_id = @OrgId)
			BEGIN
				--Insert Workflow templates from default workflow templates
				INSERT INTO TWorkflowTemplate (fk_company_id, Name, IsEmail, IsPost, IsFax, [Type], IsDefault)
				SELECT	@CompanyId, Name, IsEmail, IsPost, IsFax, [Type], IsDefault
				FROM	MFO_DEFAULT.DBO.TDefaultWorkflowTemplate WHERE fk_organization_id = @OrgId;

				--Insert Workflow template content from default workflow template content
				INSERT	TWorkflowTemplateContent (fk_template_id, [fk_company_id], fk_language_id, [Text], [Subject])
				SELECT	WT.Id, WT.fk_company_id, C.fk_language_id, C.[Text], C.[Subject]
				FROM	MFO_DEFAULT.DBO.TDefaultWorkflowTemplateContent C JOIN
						MFO_DEFAULT.DBO.TDefaultWorkflowTemplate DT ON C.fk_template_id = DT.Id AND DT.fk_organization_id = @OrgId JOIN
						TWorkflowTemplate WT ON WT.[Type] COLLATE DATABASE_DEFAULT = DT.[Type] COLLATE DATABASE_DEFAULT AND 
						WT.fk_company_id = @CompanyId AND WT.Name COLLATE DATABASE_DEFAULT = DT.Name COLLATE DATABASE_DEFAULT
			END
		ELSE
			BEGIN
				--Insert Workflow templates from default workflow templates
				INSERT INTO TWorkflowTemplate (fk_company_id, Name, IsEmail, IsPost, IsFax, [Type], IsDefault)
				SELECT	@CompanyId, Name, IsEmail, IsPost, IsFax, [Type], IsDefault
				FROM	MFO_DEFAULT.DBO.TDefaultWorkflowTemplate WHERE fk_organization_id IS NULL;

				--Insert Workflow template content from default workflow template content
				INSERT	TWorkflowTemplateContent (fk_template_id, [fk_company_id], fk_language_id, [Text], [Subject])
				SELECT  WT.Id, WT.fk_company_id,C.fk_language_id, C.[Text], C.[Subject]
				FROM	MFO_DEFAULT.DBO.TDefaultWorkflowTemplateContent C JOIN
						MFO_DEFAULT.DBO.TDefaultWorkflowTemplate DT ON C.fk_template_id = DT.Id AND DT.fk_organization_id IS NULL JOIN
						TWorkflowTemplate WT ON WT.[Type] COLLATE DATABASE_DEFAULT = DT.[Type] COLLATE DATABASE_DEFAULT AND 
						WT.fk_company_id = @CompanyId AND WT.Name COLLATE DATABASE_DEFAULT = DT.Name COLLATE DATABASE_DEFAULT
			END
	END

	INSERT	[dbo].[TTitle] ([fk_company_id], [Code], [Description], [Heading], [Abbreviation], [fk_lang_id], [Gender], [CreDate], [CreTime], [CreUsr])
	SELECT	@CompanyId, [Code], [Description], [Heading], [Abbreviation], [fk_lang_id], [Gender], GETDATE(), CAST( GETDATE() as time), 'System'
	FROM	[MFO_DEFAULT].[dbo].[TDefaultTitle];

	INSERT	[dbo].[TSequence] ([fk_company_id], [Name], [Increment], [LastNumber])
	SELECT	@CompanyId, [Name], [Increment], [LastNumber]
	FROM	[MFO_DEFAULT].[dbo].[TDefaultSequence];
	
	DECLARE @SoftwareId int, @countryId int;
	SELECT	@SoftwareId = fk_software_id, @countryId = fk_country_id FROM gateway.TCompany WHERE Id = @CompanyId;

	DECLARE @LegalForm varchar(20) = ''
	SELECT @LegalForm = l.Code FROM gateway.TCompany c
	JOIN MFO_GLOBAL.dbo.TLegalForm l on c.fk_legalform_id = l.Id
	 WHERE c.Id = @CompanyId 

	IF (NOT EXISTS(SELECT top 1 Id from TLayoutView where fk_company_id = @CompanyId))
	BEGIN
		INSERT	[dbo].[TLayoutView] ([fk_company_id], [Name], [DescriptionCode])
		SELECT	@CompanyId, [Name], [DescriptionCode]
		FROM	[MFO_DEFAULT].[dbo].[TDefaultLayoutView];
	END

		DECLARE @viewId int;
		
	IF(NOT EXISTS(SELECT top 1 Id from TLayout where fk_company_id = @CompanyId AND [Description] IN ('WF Sales Order Details','WF Sales Details','WFPurchase Order Details','WF Purchase Details')))
	BEGIN
		IF (@IsWorkflow = 1)
		BEGIN
			--Insert layouts for WF sales layout views
			SELECT	@viewId = Id FROM [TLayoutView]	where fk_company_id = @CompanyId AND [Name] = 'vw_WFSales';
			INSERT	[dbo].[TLayout] ([fk_company_id], [fk_layoutview_id], [LayoutType], [Content], [Description], [LayoutCategory], [TempContent], [CreDate], [CreTime], [CreUsr]) 
			SELECT	@CompanyId, @viewId, [LayoutType], [Content], [Description], 0, [TempContent], GETDATE(), CAST( GETDATE() as time), 'System'
			FROM	[MFO_DEFAULT].[dbo].[TDefaultLayout]
			WHERE	[Description] IN ('WF Sales Order Details','WF Sales Details');

			--Insert layouts for WF purchase layout views
			SELECT	@viewId = Id FROM [TLayoutView]	where fk_company_id = @CompanyId AND [Name] = 'vw_WFPurchase';
			INSERT	[dbo].[TLayout] ([fk_company_id], [fk_layoutview_id], [LayoutType], [Content], [Description], [LayoutCategory], [TempContent], [CreDate], [CreTime], [CreUsr]) 
			SELECT	@CompanyId, @viewId, [LayoutType], [Content], [Description], 0, [TempContent], GETDATE(), CAST( GETDATE() as time), 'System'
			FROM	[MFO_DEFAULT].[dbo].[TDefaultLayout] 
			WHERE	[Description] IN ('WF Purchase Order Details','WF Purchase Details');
		END
	END	

	IF(NOT EXISTS(SELECT top 1 Id from TLayout where fk_company_id = @CompanyId AND [Description] IN ('Sales invoice duplicate euro','Sales invoice report euro')))
	BEGIN
		IF (@IsInvoicing = 1 AND @IsInvoicingTemplate = 1)
		BEGIN
			--Insert layouts for Invoice layout views
			SELECT	@viewId = Id FROM [TLayoutView]	where fk_company_id = @CompanyId AND [Name] = 'vw_GetInvoiceDetails';
			INSERT	[dbo].[TLayout] ([fk_company_id], [fk_layoutview_id], [LayoutType], [Content], [Description], [LayoutCategory], [TempContent], [CreDate], [CreTime], [CreUsr]) 
			SELECT	@CompanyId, @viewId, [LayoutType], [Content], [Description], 0, [TempContent], GETDATE(), CAST( GETDATE() as time), 'System'
			FROM	[MFO_DEFAULT].[dbo].[TDefaultLayout]
			WHERE	[Description] IN ('Sales invoice duplicate euro','Sales invoice report euro')
					OR (@countryId = 167 AND [Description] IN ('Sales PHP', 'Sale USD')); --For PH must be added layouts Sales PHP and Sales USD	
		END
	END

	IF(NOT EXISTS(SELECT top 1 Id from TLayout where fk_company_id = @CompanyId AND [Description] IN ('Sales order report euro','Sales order duplicate euro', 'Sales order duplicate')))
	BEGIN
		IF (@IsOrder =1 AND @IsOrderTemplate = 1)
		BEGIN
			--Insert layouts for order layout views
			SELECT	@viewId = Id FROM [TLayoutView]	where fk_company_id = @CompanyId AND [Name] = 'vw_GetInvoiceDetails';
			INSERT	[dbo].[TLayout] ([fk_company_id], [fk_layoutview_id], [LayoutType], [Content], [Description], [LayoutCategory], [TempContent], [CreDate], [CreTime], [CreUsr]) 
			SELECT	@CompanyId, @viewId, [LayoutType], [Content], [Description], 0, [TempContent], GETDATE(), CAST( GETDATE() as time), 'System'
			FROM	[MFO_DEFAULT].[dbo].[TDefaultLayout]
			WHERE	[Description] IN ('Sales order report euro','Sales order duplicate euro', 'Sales order duplicate')
					OR (@countryId = 167 AND [Description] IN ('Sales PHP', 'Sale USD')); --For PH must be added layouts Sales PHP and Sales USD	
		END
	END

	IF(NOT EXISTS(SELECT top 1 Id from TLayout where fk_company_id = @CompanyId AND [Description] IN ('Sales credit duplicate euro', 'Sales credit report euro')))
	BEGIN
		IF (((@IsInvoicing = 1 AND @IsInvoicingTemplate = 1) OR (@IsOrder =1 AND @IsOrderTemplate = 1)) AND (@IsWorkflow = 0))
		BEGIN 
			--Insert layouts for order layout views
			SELECT	@viewId = Id FROM [TLayoutView]	where fk_company_id = @CompanyId AND [Name] = 'vw_GetInvoiceDetails';
			INSERT	[dbo].[TLayout] ([fk_company_id], [fk_layoutview_id], [LayoutType], [Content], [Description], [LayoutCategory], [TempContent], [CreDate], [CreTime], [CreUsr]) 
			SELECT	@CompanyId, @viewId, [LayoutType], [Content], [Description], 0, [TempContent], GETDATE(), CAST( GETDATE() as time), 'System'
			FROM	[MFO_DEFAULT].[dbo].[TDefaultLayout]
			WHERE	[Description] IN ('Sales credit duplicate euro', 'Sales credit report euro')
					OR (@countryId = 167 AND [Description] IN ('Sales PHP', 'Sale USD')); --For PH must be added layouts Sales PHP and Sales USD
			
		END
	END

	IF(NOT EXISTS(SELECT top 1 Id from TVATCode where fk_company_id = @CompanyId) AND (@SoftwareId = 3 OR @SoftwareId = 4 OR @SoftwareId = 1 OR @SoftwareId = 17 OR @SoftwareId = 24 OR @SoftwareId = 26 OR @SoftwareId = 31))
		BEGIN
			DECLARE @Cnt int
			DECLARE @VATId int
			DECLARE @VATCode nchar(10)
			DECLARE @VATTranType int

			DECLARE vatDef CURSOR FOR 
			SELECT v.Id, v.Code, v.TransactionType	
			FROM [MFO_DEFAULT].[dbo].[TDefaultVATCode] v, [MFO_DEFAULT].[dbo].[TDefaultTranslation] t
			WHERE v.fk_software_id = @SoftwareId 
            AND v.DescriptionCode = t.Code
			AND v.UseBookkeeping = @UseBookkeeping
            AND t.UseBookkeeping = @UseBookkeeping
			OR (((@LegalForm is not null AND @LegalForm <> '' AND @LegalForm = LegalForm AND fk_country_id = @countryId) OR (@LegalForm is null OR @LegalForm = '')))
			OPEN vatDef FETCH NEXT FROM vatDef INTO @VATId, @VATCode, @VATTranType

			WHILE @@FETCH_STATUS = 0
				BEGIN
					DECLARE @IdVat int
					Select @IdVat = 0
					SET @Cnt = 0

					SELECT @Cnt = count(*) 
					FROM TVATCode 
					WHERE Code = @VATCode 
					  AND TransactionType = @VATTranType
					  AND fk_company_id = @CompanyId

					IF (@Cnt > 0)
						BEGIN
							Select @IdVat = ISNULL(COALESCE(Id, 0), '0') from TVATCode where Code = @VATCode and TransactionType = @VATTranType and fk_company_id = @CompanyId
						END

					IF (@IdVat < 1)
						BEGIN
							INSERT	[dbo].[TVATCode] ([fk_company_id], [Code], [DescriptionCode], [LegalStipulation], [VATPerc], [VATPercIncl], [Blocked], [VATChargedPurchase], [ECSalesList], [TransactionType], 
									[IsSystem], [VATPercType], [Charged],[IsEU],[IsNotEU],[IsSameCountry],[Name],[GenTaxRate],[WithholdingTax],[SetRate],[Status],[SalesTaxRate],[SalesAccountName],[PurchaseTaxRate],[PurchaseAccountName],
									[WithholdingTransactionType],[WithholdingPurchaseTaxRate],[WithholdingPurchaseAccountName],[WithholdingSalesTaxRate],[WithholdingSalesAccountName],[IsPH],
									[fk_vatcodetype_id], [CreDate], [CreTime], [CreUsr]) 
							SELECT	@CompanyId, [Code], [DescriptionCode], [LegalStipulation], [VATPerc], [VATPercIncl], [Blocked], [VATChargedPurchase], [ECSalesList], [TransactionType], 
									[IsSystem], [VATPercType], [Charged],[IsEU],[IsNotEU],[IsSameCountry],[Name],[GenTaxRate],[WithholdingTax],[SetRate],[Status],[SalesTaxRate],[SalesAccountName],[PurchaseTaxRate],[PurchaseAccountName],
									[WithholdingTransactionType],[WithholdingPurchaseTaxRate],[WithholdingPurchaseAccountName],[WithholdingSalesTaxRate],[WithholdingSalesAccountName],[IsPH],
									[fk_vatcodetype_id], GETDATE(), CAST( GETDATE() as time), 'System'
							FROM	[MFO_DEFAULT].[dbo].[TDefaultVATCode]
							WHERE Id = @VATId


						END

					FETCH NEXT FROM vatDef INTO @VATId, @VATCode, @VATTranType
				END

				INSERT	[dbo].[TTranslation] ([fk_company_id], [fk_language_id], [Code], [Description], [IsBuiltIn], [CreDate], [CreTime], [CreUsr]) 
				SELECT @CompanyId, fk_language_id, Code, Description, IsBuiltIn,  GETDATE(), CAST( GETDATE() as time), 'System'
				FROM [MFO_DEFAULT].[dbo].[TDefaultTranslation] 
				WHERE UseBookkeeping = @UseBookkeeping AND Code in (SELECT DescriptionCode FROM [dbo].[TVATCode] WHERE fk_company_id=@CompanyId) AND (fk_country_id = @countryId) 
	
			CLOSE vatDef
			DEALLOCATE vatDef
		END

	IF @SoftwareId = 1 -- MFO
	BEGIN		
		--Check if there is country specific payment condition. If there is then use them else use default.
		DECLARE @hasPaymentCond INT;
		SELECT @hasPaymentCond = COUNT(Id) from [MFO_DEFAULT].[dbo].[TDefaultPaymentCondition] WHERE fk_country_id = @countryId;
		
		INSERT	[dbo].[TPaymentCondition] ([fk_company_id],[Code],[DescriptionCode],[PaymentMethod],[DueDateNbrTimesEndMonth],[DueDateNbrDays],[DiscountNbrDays],
				[Percentage],[IsDiscountCalcInclVAT],[IsDiscountCalcMethodIncl],[Description],[CreDate], [CreTime], [CreUsr])
		SELECT	@CompanyId, [Code],[DescriptionCode],[PaymentMethod],[DueDateNbrTimesEndMonth],[DueDateNbrDays],[DiscountNbrDays],
				[Percentage],[IsDiscountCalcInclVAT],[IsDiscountCalcMethodIncl],[Description], GETDATE(), CAST( GETDATE() as time), 'System'
		FROM	[MFO_DEFAULT].[dbo].[TDefaultPaymentCondition]
		WHERE	(@hasPaymentCond = 0 AND fk_country_id IS NULL);
		
		INSERT	[dbo].[TTranslation] ([fk_company_id], [fk_language_id], [Code], [Description], [IsBuiltIn], [CreDate], [CreTime], [CreUsr]) 
		SELECT	@CompanyId, [fk_language_id], [Code], [Description], [IsBuiltIn], GETDATE(), CAST( GETDATE() as time), 'System'
		FROM	[MFO_DEFAULT].[dbo].[TDefaultTranslation]
		WHERE	[fk_country_id] is null AND [Code] IN (SELECT DescriptionCode FROM [dbo].[TPaymentCondition] WHERE fk_company_id = @CompanyId)
	END

	--IF @SoftwareId = 26
	--BEGIN
	--	EXEC [MFO_GLOBAL].[dbo].[sp_api_InsertDefaultProfileCompanyXero] @CompanyId, @countryId, @SoftwareId, '', ''
	--END
END
