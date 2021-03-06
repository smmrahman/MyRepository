--ALTER PROCEDURE [dbo].[pr_Admin_Build_MasterLog]
--AS
---------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE
	@vSource	VARCHAR (20)
SELECT
	@vSource = 'All'
--	, @vLoadDate = GETDATE ()

IF	OBJECT_ID ('tempDB..#temp_Source')	IS NOT NULL	DROP TABLE #temp_Source
CREATE	TABLE #temp_Source (
	SourceSystemDesc	VARCHAR (20)
)

IF	@vSource = 'ALL'
BEGIN
	INSERT	INTO #temp_Source SELECT DISTINCT SourceSystemDesc FROM YodilIDS_Warehouse.Control.SourceSystem
END
ELSE
BEGIN
	INSERT	INTO #temp_Source SELECT @vSource
END
-- select * from #temp_Source

IF	OBJECT_ID ('tempDB.dbo.#temp_MasterLog') IS	NOT NULL	DROP TABLE #temp_MasterLog
SELECT DISTINCT
	LoadDate = CONVERT (VARCHAR (10), prem.xRefPolicyLevelStartDate, 120)
	, AsofDate = CONVERT (VARCHAR (8), GETDATE () - 1, 112)
--	, Rno = prem.PolicyTransactionID
	, Sort_Order = CONVERT (INT, NULL)
	, SourceSystemName = CONVERT (VARCHAR (50), ss.SourceSystemDesc)
	, SubmissionNumber = CONVERT (VARCHAR (500), p.MasterPolicyNumber)
	, DuckCreekSubmissionNumber = CONVERT (VARCHAR (500), CASE WHEN ss.SourceSystemDesc LIKE 'BHSI%' THEN p.MasterPolicyNumber ELSE '' END)
	, MasterPolicyNumber = CONVERT (VARCHAR (500), CASE	WHEN	p.PolicyType = 'P' THEN	p.PolicyNumber ELSE '' END)
	, NewRenewal = CONVERT (VARCHAR (500), CASE	WHEN	p.NewRenewalType = 'N' THEN 'New'
											WHEN	p.NewRenewalType = 'R' THEN 'Renewal'
											ELSE	''
									END)
	, InsuredName = CONVERT (VARCHAR (500), NULL)
	, AdvisenId = CONVERT (VARCHAR (100), NULL)
	, ReasonCodeMeaning = CONVERT (VARCHAR (500), NULL)
	, Underwriter = CONVERT (VARCHAR (500), NULL)
--	, ProductLine = CASE	WHEN	pdt.ProductDesc = 'EP' THEN	'Exec & Prof'
--											ELSE pdt.ProductDesc
--								END
	, ProductLine = CONVERT (VARCHAR (100), '')
	, ProductLineSubType = CONVERT (VARCHAR (200), ISNULL (LTRIM (RTRIM (cp.ProductLineSubType)), NULL))
	, Section = CONVERT (VARCHAR (200), ISNULL (LTRIM (RTRIM (cp.SectionNumber)), NULL))
	, ProfitCode = CONVERT (VARCHAR (200), ISNULL (LTRIM (RTRIM (cp.ProfitCode)), NULL))
	, ProjectType = CONVERT (VARCHAR (100), '')
	, ISOCode = CONVERT (VARCHAR (100), '')
	, CurrentStatus = CONVERT (VARCHAR (100), REPLACE (prem.TransactionType, 'Adj - ', ''))
	, EffectiveDate = CONVERT (DATE, prem.TransactionEffectiveDate, 120)
	, ExpiryDate = CONVERT (DATE, p.ExpirationDate, 120)
	, ProcessDate = CONVERT (DATE, CASE	WHEN	p.PolicyType <> 'P' THEN NULL
																							ELSE	prem.ProcessDate
																				END)
	, BindDate = CONVERT (DATE, CASE WHEN p.PolicyType = 'P' THEN p.StartDate ELSE NULL END, 120) 
	, Renewable = CASE	WHEN	p.NonRenewalInd = 'N' THEN 'Yes'
										WHEN	p.NonRenewalInd = 'Y' THEN 'No'
										ELSE	NULL
							END
	, DateOfRenewal =	CONVERT (DATE, CASE	WHEN	p.NonRenewalInd = 'N' THEN p.ExpirationDate
																									ELSE	NULL
																						END, 120)
	, PolicyType = CONVERT (VARCHAR (100), '')	
	, DirectAssumed = p.AssumedDirectType
	, CompanyPaper = CASE WHEN w.WritingCompanyCode = 'COMPP_NUL' THEN NULL ELSE w.WritingCompanyDesc END
	, CompanyPaperNumber = case when w.WritingCompanyCode='COMPP_NUL' then NULL else w.WritingCompanyCode end
	, Coverage = CASE	WHEN	p.PolicyType = 'P' 
										THEN	CASE	WHEN p.PolicyNumber LIKE '%Not Applicable%' THEN 'Not Applicable'
																ELSE SUBSTRING (p.PolicyNumber, 4, 3) 
													END
									ELSE '' 
						END
	, PolicyNumber = CONVERT (VARCHAR (6), CASE	WHEN	p.PolicyType = 'P'	
																						THEN	CASE	WHEN	p.PolicyNumber LIKE '%Not Applicable%' THEN SUBSTRING (p.PolicyNumber, 19, 6)
--																												WHEN	p.PolicyNumber LIKE '%NT/APP%' THEN 'NT/APP'
	--																											WHEN	p.PolicyNumber LIKE '%NT/AAP%' THEN 'NT/AAP'
		--																										WHEN	p.PolicyNumber LIKE '%NTapp/%' THEN 'NTapp/'
																												ELSE	SUBSTRING (p.PolicyNumber, 8, 6)
																									END
																					ELSE CASE WHEN ss.SourceSystemDesc = 'ODS' THEN NULL
																										ELSE	SUBSTRING (p.MasterPolicyNumber, 	8, 6)
																							END
																		END)
	, Suffix = CASE	WHEN	p.PolicyType = 'P'	THEN	RIGHT (p.PolicyNumber, 2)	ELSE ''		END
	, TransactionNumber = CONVERT (VARCHAR (100), prem.PolicyTransactionID)
	, AdmittedNonAdmitted =		CASE	WHEN	p.NonAdmittedInd = 'A'	THEN	CASE	WHEN	p.AdmittedType IN ('Admitted - Assumed Reinsurance', 'Assumed Reinsurance') THEN 'Admitted - Assumed Reinsurance'
																																					WHEN	p.AdmittedType IN ('Admitted - Canada', 'CANADA') THEN 'Admitted - Canada'
																																					WHEN	p.AdmittedType IN ('Admitted - DEREGSTATE', 'DEREGSTATE') THEN 'Admitted - De-Reg State'
																																					WHEN	p.AdmittedType IN ('Admitted - Deregulated', 'Deregulated') THEN 'Admitted - Deregulated'
																																					WHEN	p.AdmittedType IN ('Admitted - Filed', 'Filed') THEN 'Admitted - Filed'
																																					WHEN	p.AdmittedType IN ('Admitted - FILEDADMITTED', 'FILEDADMITTED') THEN 'Admitted - Filed Admitted'
																																					WHEN	p.AdmittedType IN ('Admitted - Non-Filed', 'Non-Filed') THEN 'Admitted - Non-Filed'
																																					WHEN	p.AdmittedType IN ('Admitted - NYFREETRADE', 'NYFREETRADE') THEN 'Admitted - NY Free Trade'
																																					WHEN	p.AdmittedType IN ('Admitted - NY FTZ', 'NY FTZ') THEN 'Admitted - NY FTZ'
																																					WHEN	p.AdmittedType IN ('Admitted - Reinsurance', 'REINSURANCE') THEN 'Admitted - Reinsurance'
																																					ELSE	'Admitted'
																																			END
																	WHEN	p.NonAdmittedInd = 'N'	THEN	CASE	WHEN p.AdmittedType IN ('Assumed - Reinsurance') THEN 'Non-Admitted - Assumed - Reinsurance'
																																					--WHEN p.AdmittedType IN ('DEREGSTATE') THEN 'Non-Admitted - DEREGSTATE'
																																					--WHEN p.AdmittedType IN ('FILEDADMITTED') THEN 'Non-Admitted - FILEDADMITTED'
																																					--WHEN p.AdmittedType IN ('NYFREETRADE') THEN 'Non-Admitted - NYFREETRADE'
																																					WHEN p.AdmittedType IN ('DEREGSTATE') THEN 'Non-Admitted'
																																					WHEN p.AdmittedType IN ('FILEDADMITTED') THEN 'Non-Admitted'
																																					WHEN p.AdmittedType IN ('NYFREETRADE') THEN 'Non-Admitted'
																																					ELSE	'Non-Admitted'
																																		END
																	ELSE	NULL
															END
	, ClassName = CONVERT (VARCHAR (100), '')
	, ClassCode = CONVERT (VARCHAR (100), '')
	, BrokerName = CONVERT (VARCHAR (100), NULL)
	, BrokerType = CONVERT (VARCHAR (100), NULL)
	, AlternativeAddress1 = CONVERT (VARCHAR (100), NULL)
	, BrokerContactPerson = CONVERT (VARCHAR (100), NULL)
	, BrokerCountry = CONVERT (VARCHAR (100), NULL)
	, BrokerState = CONVERT (VARCHAR (100), NULL)
--	, BrokerCity = CONVERT (VARCHAR (100), '(Unknown)-0000')
	, BrokerCity = CONVERT (VARCHAR (100), NULL)
	, BrokerContactPersonStreetAddress = CONVERT (VARCHAR (100), NULL)
	, BrokerContactPersonZipCode = CONVERT (VARCHAR (100), NULL)
	, BrokerCode = CONVERT (VARCHAR (100), NULL)
	, BrokerContactPersonEmail = CONVERT (VARCHAR (100), NULL)
	, BrokerContactPersonNumber = CONVERT (VARCHAR (100), NULL)
	, BrokerContactPersonMobile = CONVERT (VARCHAR (100), NULL)	
	, RetailBroker = CONVERT (VARCHAR (100), NULL)
	, RetailBrokerCountry = CONVERT (VARCHAR (100), NULL)
	, RetailBrokerState = CONVERT (VARCHAR (100), NULL)
	, RetailBrokerCity = CONVERT (VARCHAR (100), NULL)
	, BrancOffice = CONVERT (VARCHAR (100), NULL)
	, Currency = CONVERT (VARCHAR (100), prem.CurrencyCode)
--	, ExchangeRate = CONVERT (VARCHAR (100), '')
	, ExchangeRate = CONVERT (DECIMAL (13, 6), CASE WHEN prem.CurrencyCode = 'USD' THEN 1 ELSE NULL END)
	, ExchangeDate = CONVERT (VARCHAR (10), prem.TransactionDate, 120)
	, LayerofLimitInLocalCurrency =	CONVERT (NUMERIC (19, 2), NULL)
	, LayerofLimitInUSD =	CONVERT (NUMERIC (19, 2), NULL)
	, PercentageofLayer =	CONVERT (NUMERIC (19, 2), NULL)
	, Limit = CONVERT (NUMERIC (19, 2), NULL)
	, LimitUSD = CONVERT (NUMERIC (19, 2), NULL)
	, AttachmentPoint = CONVERT (NUMERIC (19, 2), NULL)
	, AttachmentPointUSD = CONVERT (NUMERIC (19, 2), NULL)
	, SelfInsuredRetentionInLocalCurrency = CONVERT (VARCHAR (100), '')
	, SelfInsuredRetentionInUSD = CONVERT (VARCHAR (100), '')
	, OriginalPremium = CONVERT (NUMERIC (19, 2), prem.Src_TransactionAmount_OC)
	, GrossPremiumUSD = CONVERT (NUMERIC (19, 2), prem.Src_TransactionAmount)
	, PolicyCommPercentage = CONVERT (NUMERIC (19, 2), 0)
	, PolicyCommInLocalCurrency = CONVERT (NUMERIC (19, 2), 0)
	, PolicyCommInUSD = CONVERT (NUMERIC (19, 2), 0)
	, PremiumNetofCommInLocalCurrency = CONVERT (NUMERIC (19, 2), 0)
	, PremiumNetofCommInUSD = CONVERT (NUMERIC (19, 2), 0)
	, ReasonCode = CONVERT (VARCHAR (100), '')
	, CabCompanies = CONVERT (VARCHAR (100), '')
	, TotalInsuredValue = CONVERT (NUMERIC (16, 2), 0)
	, TotalInsuredValueInUSD = CONVERT (NUMERIC (16, 2), 0)
	, AlternativeZipCode = CONVERT (VARCHAR (100), '')
	, AlternativeState = CONVERT (VARCHAR (100), '')
	, RiskProfile = CONVERT (VARCHAR (100), '')
	, ProjectName = CONVERT (VARCHAR (1000), '')
	, GeneralContractor = CONVERT (VARCHAR (100), '')
	, ProjectOwnerName = CONVERT (VARCHAR (100), '')
	, ProjectStreetAddress = CONVERT (VARCHAR (1000), '')
	, ProjectCountry = CONVERT (VARCHAR (100), '')
	, ProjectState = CONVERT (VARCHAR (100), '')
	, ProjectCity = CONVERT (VARCHAR (100), '')
	, BidSituation = CONVERT (VARCHAR (100), '')
	, ReinsuredCompany = CONVERT (VARCHAR (100), '')
	, DBNumber = CONVERT (VARCHAR (100), '')
	, NAICCode = CONVERT (VARCHAR (500), '')
	, NAICTitle = CONVERT (VARCHAR (500), '')
	, OfrcReport = CONVERT (VARCHAR (100), '')
	, DBAName = CONVERT (VARCHAR (100), '')
	, InsuredCountry = CONVERT (VARCHAR (100), '')
	, InsuredState = CONVERT (VARCHAR (100), '')
	, InsuredCity = CONVERT (VARCHAR (100), '')
	, InsuredMailingAddress1 = CONVERT (VARCHAR (100), '')
	, InsuredZipcode = CONVERT (VARCHAR (100), '')
	, InsuredContactPerson = CONVERT (VARCHAR (100), '')
	, InsuredContactPersonEmail = CONVERT (VARCHAR (100), '')
	, InsuredContactPersonPhone = CONVERT (VARCHAR (100), '')
	, InsuredContactPersonMobile = CONVERT (VARCHAR (100), '')
	, InsuredSubmissionDate = CONVERT (VARCHAR (100), '')
	, insuredQuoteDueDate = CONVERT (VARCHAR (100), '')
	, ByBerksiFromBroker = CONVERT (VARCHAR (100), '')
	, ByIndiaFromBerksi = CONVERT (VARCHAR (100), '')
	, Date1 = CONVERT (VARCHAR (10), '')
	, Status1 = CONVERT (VARCHAR (100), '')
	, Remark1 = CONVERT (VARCHAR (100), '')
	, Date2 = CONVERT (DATETIME, '')
	, Status2 = CONVERT (VARCHAR (100), '')
	, Remark2 = CONVERT (VARCHAR (100), '')
	, Date3 = CONVERT (DATETIME, '')
	, Status3 = CONVERT (VARCHAR (100), '')
	, Remark3 = CONVERT (VARCHAR (100), '')
	, Date4 = CONVERT (DATETIME, '')
	, Status4 = CONVERT (VARCHAR (100), '')
	, Remark4 = CONVERT (VARCHAR (100), '')
	, Date5 = CONVERT (DATETIME, '')
	, Status5 = CONVERT (VARCHAR (100), '')
	, Remark5 = CONVERT (VARCHAR (100), '')
	, DateForAmendment = GETDATE ()
	, AttachmentType = CASE	WHEN	p.PrimaryExcessIndicator = 'P' THEN 'Primary'
													WHEN	p.PrimaryExcessIndicator = 'E' THEN 'Excess'
													WHEN	p.PrimaryExcessIndicator = 'L' THEN NULL
													ELSE	p.PrimaryExcessIndicator
										END
	, IssuingOffice = CONVERT (VARCHAR (100), '')																																												-- Underwriter.IssuingUnderwritingOffice
	, IssuingUnderwriter = CONVERT (VARCHAR (100), '')																																										-- issue.FullName
	, deductibleinLocalCurrency = CONVERT (NUMERIC (16, 2), 0)
	, deductibleinUSD = CONVERT (NUMERIC (16, 2), 0)
--	, ActualProcessDate = CONVERT (VARCHAR (25), CASE	WHEN	ss.SourceSystemDesc = 'ODS' AND	p.PolicyType <> 'P' THEN NULL
--																										ELSE	prem.TransactionDate
--																							END, 101)
	, ActualProcessDate = CONVERT (VARCHAR (25), prem.TransactionDate, 101)
	, latitude = CONVERT (VARCHAR (100), '')
	, longitude = CONVERT (VARCHAR (100), '')
	, Affiliation = CONVERT (VARCHAR (100), '')
	, CertificateBondNumber = CONVERT (VARCHAR (100), '')
	, RiskCountry = CONVERT (VARCHAR (100), '')
	, SourceSystemDesc = ss.SourceSystemDesc
	, Region	= CONVERT (VARCHAR (20), '')
	, Occupancy = CONVERT (VARCHAR (100), CASE WHEN ss.SourceSystemDesc LIKE 'BHSI%' THEN '' ELSE NULL END)
	, NumberOfLocations = CONVERT (VARCHAR (100), CASE WHEN ss.SourceSystemDesc LIKE 'BHSI%' THEN 'No' ELSE NULL END)
	, SourceSystemInsuredId = CONVERT (VARCHAR (100), NULL) 
	, GUPAdvisenId = CONVERT (VARCHAR (100), NULL) 
	, AdvisenUltimateParentCompanyName = CONVERT (VARCHAR (200), NULL) 
	, AdvisenTicker = CONVERT (VARCHAR (100), NULL) 
	, AdvisenSicPrimaryNumeric = CONVERT (VARCHAR (100), NULL) 
	, AdvisenSicPrimaryNumericDesc = CONVERT (VARCHAR (100), NULL) 
	, AdvisenRevenue = CONVERT (VARCHAR (100), NULL) 
	, AdvisenDescOfOperations = CONVERT (VARCHAR (100), NULL) 

	, p.PolicyKey
	, PolicyID = p.PolicyID
	, CustomPolicyID = 0
	, OldMasterPolicyNumber = p.MasterPolicyNumber 
	, OldPolicyNumber = p.PolicyNumber 
	, PremMasterPolicyNumber = prem.MasterPolicyNumber
	, OldPolicyType = p.PolicyType
	, PolicyStatus = s.SourceStatusDesc
	, StatusCaption = ssr.SourceStatusReasonDesc
	, TransactionType = REPLACE (prem.TransactionType, 'Adj - ', '')																					--prem.TransactionType
	, EDWStatus = CONVERT (VARCHAR (100), ssr.SourceStatusReasonDesc)
	, TransactionDate = CONVERT (VARCHAR (10), prem.TransactionDate, 120)
	, TransactionDateTime = prem.TransactionDate
	, PolicyTransactionKey  = prem.PolicyTransactionKey 
	, StatusReasonID = p.StatusReasonID
	, PolicyTransactionID = prem.PolicyTransactionID
	, SourceSystemID = p.SourceSystemId 
	, SourceSystemPolicyID = p.SourceSystemPolicyID
	, PolicyGlobalMasterId = p.PolicyGlobalMasterId
	, PolicyLevelsCompoundId = prem.PolicyLevelsCompoundID 
	, RunningTransactionAmount_OC = prem.RunningTransactionAmount_OC
	, RunningTransactionAmount = prem.RunningTransactionAmount
	, RootDctId = CASE	WHEN ss.SourceSystemDesc LIKE 'BHSI%' AND ISNULL (prem.PolicyTransactionKey, '') <> '' THEN LEFT (prem.PolicyTransactionKey, CHARINDEX ('||', prem.PolicyTransactionKey) - 1)
										ELSE	0
							END
	, HistoryId = CASE	WHEN ss.SourceSystemDesc LIKE 'BHSI%' AND ISNULL (prem.PolicyTransactionKey, '') <> '' THEN LEFT (RIGHT (prem.PolicyTransactionKey, LEN (prem.PolicyTransactionKey) - CHARINDEX ('||', prem.PolicyTransactionKey) - 1), CHARINDEX ('||', RIGHT (prem.PolicyTransactionKey, LEN (prem.PolicyTransactionKey) - CHARINDEX ('||', prem.PolicyTransactionKey) - 1)) -1)
										ELSE	0
							END
	, DeletedFlag = CONVERT (INT, 0)
INTO
	#temp_MasterLog
--select top 100 prem.*
FROM 
	YodilIDS_Warehouse.Policy.Policy p 

	JOIN YodilIDS_Warehouse.Policy.XrefPolicyLevels x
		ON x.PolicyId = p.PolicyId

	LEFT JOIN YodilIDS_Warehouse.[Policy].[WritingCompany] w 
		ON p.WritingCompanyId = w.WritingCompanyId

	LEFT JOIN YodilIDS_Warehouse.[Shared].[SourceStatus] s
		ON	p.StatusId = s.SourceStatusId 

	LEFT JOIN YodilIDS_Warehouse.[Shared].[SourceStatusReason] ssr
		ON	p.StatusReasonId = ssr.SourceStatusReasonId 

	LEFT JOIN YodilIDS_Warehouse.[Custom].[Policy] cp
		ON p.PolicyID = cp.PolicyID

	LEFT JOIN YodilIDS_Warehouse.[Control].SourceSystem ss
		ON	p.SourceSystemID = ss.SourceSystemID

	JOIN	 EDW.dbo.BHSI_Transaction prem
		ON		p.PolicyID = prem.PolicyID
		AND	prem.MeasureName IN ('GrossPremium', 'WrittenPremium', 'GrossPremiumInUSD', 'WrittenPremiumInUSD')
WHERE 
	x.EndDate ='9999-12-31'
	AND	x.PolicyLevelsCompoundID = prem.PolicyLevelsCompoundID
	AND	((ss.SourceSystemDesc LIKE 'BHSI%' AND	CONVERT (VARCHAR (10), p.EffectiveDate, 120) >= '2016-04-01') OR ss.SourceSystemDesc NOT LIKE 'BHSI%')
	AND	CONVERT (VARCHAR (10), prem.TransactionDate, 120) <= CONVERT (VARCHAR (10), GETDATE () - 1, 120)								-- @vLoadDate
	AND	ss.SourceSystemDesc IN	(SELECT	SourceSystemDesc FROM #temp_Source)		-- = @vSource
--	and p.PolicyNumber like '%000211-03%'
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 processdate, actualprocessdate, transactiondate, TransactionType, OriginalPremium, PolicyCommInLocalCurrency, * from #temp_MasterLog where submissionnumber like '15-05-03-029202%'
-- select top 100 processdate, actualprocessdate, transactiondate, TransactionNumber, OriginalPremium, PolicyCommInLocalCurrency, PolicyCommPercentage, CurrentStatus, PolicyTransactionId, * from #temp_MasterLog where masterpolicynumber like '%42-EPP-150053-04%' order by 1
-- select * from BHSI_Transaction where policynumber like '%40-SUR-300001-01%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Update Commission Fields
UPDATE
	p
SET
--select 
	PolicyCommInLocalCurrency = t.Src_TransactionAmount_OC 
	, PolicyCommInUSD = t.Src_TransactionAmount 
	, RunningTransactionAmount_OC = t.RunningTransactionAmount_OC
	, RunningTransactionAmount = t.RunningTransactionAmount
--, p.PolicyTransactionID , p.TransactionNumber, t.policytransactionid,  p.currentstatus, t.transactiontype, t.MeasureName
FROM
	#temp_MasterLog p, EDW.dbo.BHSI_Transaction t
WHERE
	p.PolicyID = t.PolicyId 
	AND	CONVERT (VARCHAR (10), p.EffectiveDate, 120) = CONVERT (VARCHAR (10), t.TransactionEffectiveDate, 120)
	AND	ISNULL (p.ProcessDate, '1900-01-01') = ISNULL (CONVERT (DATE, CASE WHEN t.PolicyType <> 'P' THEN NULL ELSE t.ProcessDate END), '1900-01-01')
	AND p.CurrentStatus = REPLACE (t.TransactionType, 'Adj - ', '')
	AND	ISNULL (p.ActualProcessDate, '01/01/00') =  ISNULL (CONVERT (VARCHAR (25), CASE WHEN t.SourceSystemDesc = 'ODS' AND t.PolicyType <> 'P' THEN NULL ELSE t.TransactionDate END, 101), '01/01/00')
--	AND	ISNULL (p.TransactionNumber , 0) = ISNULL (t.PolicyTransactionId, 0)
	AND	ISNULL (p.PolicyTransactionID, 0) = ISNULL (t.PolicyTransactionId, 0)
	AND	t.MeasureName = 'Commission'
--	and t.PolicyTransactionId = 22330338
--	and p.MasterPolicyNumber = '42-EPP-150053-04'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
 select CurrentStatus, OriginalPremium, PolicyCommInLocalCurrency, PolicyCommPercentage, ProcessDate, ActualProcessDate, * from #temp_MasterLog where MasterPolicyNumber = '40-PRI-302594-01'  
 select top 100 TransactionType, TransactionAmount_OC, Src_TransactionAmount_OC, RunningTransactionAmount_OC, * from bhsi_transaction where PolicyNumber = '42-EMC-302851-01' and measurename like 'co%' order by seq
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PremiumNetOfCommission
UPDATE
	p
SET
	PremiumNetofCommInLocalCurrency = p.OriginalPremium - ISNULL (p.PolicyCommInLocalCurrency, 0)
	, PremiumNetofCommInUSD = p.GrossPremiumUSD - ISNULL (p.PolicyCommInUSD, 0) 
FROM
	#temp_MasterLog p
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CommissionPercentage
UPDATE
	p
SET
	PolicyCommPercentage = cp.CommissionPercent * 100
FROM
	#temp_MasterLog p, EDW..v_CommissionPercent cp
WHERE
	p.PolicyID = cp.PolicyId 
	AND	p.PolicyTransactionKey = cp.PolicyTransactionKey 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from #temp_MasterLog where SubmissionNumber = '16-03-06-050255-79'
-- select top 100 processdate, actualprocessdate, transactiondate, TransactionNumber, OriginalPremium, PolicyCommInLocalCurrency, PolicyCommPercentage, * from #temp_MasterLog where masterpolicynumber like '%42-EPP-150053-04%' order by 1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Fix DuckCreekSubmissionNumber, AdmittedNonAdmitted for Sub and Quote
UPDATE
	p
SET
	DuckCreekSubmissionNumber = q.MasterPolicyNumber
	, AdmittedNonAdmitted =		CASE	WHEN	q.NonAdmittedInd = 'A'	THEN	CASE	WHEN	q.AdmittedType IN ('Admitted - Assumed Reinsurance', 'Assumed Reinsurance') THEN 'Admitted - Assumed Reinsurance'
																																					WHEN	q.AdmittedType IN ('Admitted - Canada', 'CANADA') THEN 'Admitted - Canada'
																																					WHEN	q.AdmittedType IN ('Admitted - DEREGSTATE', 'DEREGSTATE') THEN 'Admitted - De-Reg State'
																																					WHEN	q.AdmittedType IN ('Admitted - Deregulated', 'Deregulated') THEN 'Admitted - Deregulated'
																																					WHEN	q.AdmittedType IN ('Admitted - Filed', 'Filed') THEN 'Admitted - Filed'
																																					WHEN	q.AdmittedType IN ('Admitted - FILEDADMITTED', 'FILEDADMITTED') THEN 'Admitted - Filed Admitted'
																																					WHEN	q.AdmittedType IN ('Admitted - Non-Filed', 'Non-Filed') THEN 'Admitted - Non-Filed'
																																					WHEN	q.AdmittedType IN ('Admitted - NYFREETRADE', 'NYFREETRADE') THEN 'Admitted - NY Free Trade'
																																					WHEN	q.AdmittedType IN ('Admitted - NY FTZ', 'NY FTZ') THEN 'Admitted - NY FTZ'
																																					WHEN	q.AdmittedType IN ('Admitted - Reinsurance', 'REINSURANCE') THEN 'Admitted - Reinsurance'
																																					ELSE	'Admitted'
																																			END
																	WHEN	q.NonAdmittedInd = 'N'	THEN	CASE	WHEN q.AdmittedType IN ('Assumed - Reinsurance') THEN 'Non-Admitted - Assumed - Reinsurance'
																																					--WHEN q.AdmittedType IN ('DEREGSTATE') THEN 'Non-Admitted - DEREGSTATE'
																																					--WHEN q.AdmittedType IN ('FILEDADMITTED') THEN 'Non-Admitted - FILEDADMITTED'
																																					--WHEN q.AdmittedType IN ('NYFREETRADE') THEN 'Non-Admitted - NYFREETRADE'
																																					WHEN q.AdmittedType IN ('DEREGSTATE') THEN 'Non-Admitted'
																																					WHEN q.AdmittedType IN ('FILEDADMITTED') THEN 'Non-Admitted'
																																					WHEN q.AdmittedType IN ('NYFREETRADE') THEN 'Non-Admitted'
																																					ELSE	'Non-Admitted'
																																		END
																	ELSE	NULL
															END
	, CustomPolicyID = q.PolicyID
FROM
	#temp_MasterLog p, YodilIDS_Warehouse.Policy.Policy q, YodilIDS_Warehouse.Control.SourceSystem s
WHERE
	p.DuckCreekSubmissionNumber = q.PolicyNumber 
	AND	ISNULL (p.MasterPolicyNumber, '') = ''
	AND	q.EndDate = '9999-12-31'
	AND	q.PolicyType = 'P'
	AND	q.SourceSystemId = s.SourceSystemId 
	AND	p.SourceSystemName = s.SourceSystemDesc 
	AND	s.SourceSystemDesc IN	(SELECT	SourceSystemDesc FROM #temp_Source)																					--= @vSource
	AND	p.DuckCreekSubmissionNumber <> q.MasterPolicyNumber
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from #temp_MasterLog where CustomPolicyID <> 0
-- select top 100 admittednonadmitted, * from #temp_MasterLog  where masterpolicynumber = '47-PBL-150689-01'
-- select top 100 admittednonadmitted, * from #temp_MasterLog  where submissionnumber like '16-06-04-036983%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ProductLine
UPDATE
	p
SET
	ProductLine = CASE	WHEN	pl.ProductLine = 'EP' THEN	'Exec & Prof'
										ELSE pl.ProductLine
							END
FROM
	#temp_MasterLog p, EDW..v_ProductLine pl
WHERE
		p.PolicyId = pl.PolicyId
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Reassign ProductLineSubType, SectionCode and ProfitCode for Sub and Quote
UPDATE
	p
SET
	ProductLineSubType = LTRIM (RTRIM (cp.ProductLineSubType))
	, Section = LTRIM (RTRIM (cp.SectionNumber))
	, ProfitCode = LTRIM (RTRIM (cp.ProfitCode))
FROM
	#temp_MasterLog p, YodilIDS_Warehouse.Custom.Policy cp
WHERE
	p.CustomPolicyID = cp.PolicyID
	AND	p.CustomPolicyID <> 0
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
 select CurrentStatus, OriginalPremium, PolicyCommInLocalCurrency, PolicyCommPercentage, ProcessDate, * from #temp_MasterLog where MasterPolicyNumber in ('42-PRP-000345-03') order by MasterPolicyNumber, SubmissionNumber
 select top 100 TransactionType, TransactionAmount_OC, Src_TransactionAmount_OC, RunningTransactionAmount_OC, * from bhsi_transaction where PolicyNumber = '42-EMC-302851-01' and measurename like 'co%' order by seq
 select * from edw..v_nonAdditiveMeasure where PolicyId = 110099518
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select AdmittedNonAdmitted, OriginalPremium, *  from #temp_MasterLog where DuckcreekSubmissionNumber in ('15-07-03-014406', '15-08-01-016334', '15-08-03-016712', '15-09-01-017948', '43-RHC-170035-01') order by 9
-- select top 100 productlinesubtype, section, * from #temp_MasterLog  where duckcreeksubmissionnumber = '15-01-03-002707'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Deleted Flag
-- Level 1: When a Sub/Quote is bound, show only the Bound Policy.
UPDATE
	p
SET
	DeletedFlag = 1
FROM
	#temp_MasterLog p
WHERE
	p.SubmissionNumber IN (SELECT	DISTINCT SubmissionNumber 	FROM #temp_MasterLog WHERE OldPolicyType  = 'P')
	AND	p.OldPolicyType <> 'P'

-- Level 2: When a Sub/Quote is not yet bound, use the status hierarchy and transaction date to show the latest entry
/*
1.	REVISED QUOTE
1.	REVISE QUOTE 
1.	QUOTED 
2.	QUOTE INDICATION 
3.	WORKING
4.	LOST
5.	DECLINED
6.	CLOSED
7.	SHELL
8.	VOID 
8.	CANCEL-PENDING
*/
UPDATE
	p
SET
	DeletedFlag = 1
FROM
	#temp_MasterLog p
WHERE
	p.OldPolicyType <> 'P'
	AND	P.DeletedFlag = 0
	AND	p.SubmissionNumber	IN (SELECT DISTINCT SubmissionNumber FROM #temp_MasterLog WHERE StatusCaption IN ('REVISED QUOTE', 'REVISE QUOTE', 'QUOTED'))
	AND	p.StatusCaption	IN ('QUOTE INDICATION', 'WORKING', 'LOST', 'DECLINED', 'CLOSED', 'SHELL', 'VOID', 'CANCEL-PENDING')

UPDATE
	p
SET
	DeletedFlag = 1
FROM
	#temp_MasterLog p
WHERE
	p.OldPolicyType <> 'P'
	AND	P.DeletedFlag = 0
	AND	p.SubmissionNumber	IN (SELECT DISTINCT SubmissionNumber FROM #temp_MasterLog WHERE StatusCaption IN ('REVISED QUOTE', 'REVISE QUOTE', 'QUOTED'))
	AND	p.StatusCaption	IN ('QUOTE INDICATION', 'WORKING', 'LOST', 'DECLINED', 'CLOSED', 'SHELL', 'VOID', 'CANCEL-PENDING')

UPDATE
	p
SET
	DeletedFlag = 1
FROM
	#temp_MasterLog p
WHERE
	p.OldPolicyType <> 'P'
	AND	P.DeletedFlag = 0
	AND	p.SubmissionNumber	IN (SELECT DISTINCT SubmissionNumber FROM #temp_MasterLog WHERE StatusCaption IN ('QUOTE INDICATION'))
	AND	p.StatusCaption	IN ('WORKING', 'LOST', 'DECLINED', 'CLOSED', 'SHELL', 'VOID', 'CANCEL-PENDING')

UPDATE
	p
SET
	DeletedFlag = 1
FROM
	#temp_MasterLog p
WHERE
	p.OldPolicyType <> 'P'
	AND	P.DeletedFlag = 0
	AND	p.SubmissionNumber	IN (SELECT DISTINCT SubmissionNumber FROM #temp_MasterLog WHERE StatusCaption IN ('WORKING'))
	AND	p.StatusCaption	IN ('LOST', 'DECLINED', 'CLOSED', 'SHELL', 'VOID', 'CANCEL-PENDING')

UPDATE
	p
SET
	DeletedFlag = 1
FROM
	#temp_MasterLog p
WHERE
	p.OldPolicyType <> 'P'
	AND	P.DeletedFlag = 0
	AND	p.SubmissionNumber	IN (SELECT DISTINCT SubmissionNumber FROM #temp_MasterLog WHERE StatusCaption IN ('LOST'))
	AND	p.StatusCaption	IN ('DECLINED', 'CLOSED', 'SHELL', 'VOID', 'CANCEL-PENDING')

UPDATE
	p
SET
	DeletedFlag = 1
FROM
	#temp_MasterLog p
WHERE
	p.OldPolicyType <> 'P'
	AND	P.DeletedFlag = 0
	AND	p.SubmissionNumber	IN (SELECT DISTINCT SubmissionNumber FROM #temp_MasterLog WHERE StatusCaption IN ('DECLINED'))
	AND	p.StatusCaption	IN ('CLOSED', 'SHELL', 'VOID', 'CANCEL-PENDING')

UPDATE
	p
SET
	DeletedFlag = 1
FROM
	#temp_MasterLog p
WHERE
	p.OldPolicyType <> 'P'
	AND	P.DeletedFlag = 0
	AND	p.SubmissionNumber	IN (SELECT DISTINCT SubmissionNumber FROM #temp_MasterLog WHERE StatusCaption IN ('CLOSED'))
	AND	p.StatusCaption	IN ('SHELL', 'VOID', 'CANCEL-PENDING')

UPDATE
	p
SET
	DeletedFlag = 1
FROM
	#temp_MasterLog p
WHERE
	p.OldPolicyType <> 'P'
	AND	P.DeletedFlag = 0
	AND	p.SubmissionNumber	IN (SELECT DISTINCT SubmissionNumber FROM #temp_MasterLog WHERE StatusCaption IN ('SHELL'))
	AND	p.StatusCaption	IN ('VOID', 'CANCEL-PENDING')

-- Now Apply max Transaction Date logic
UPDATE
	p
SET
	DeletedFlag = 1
FROM
	#temp_MasterLog p
		JOIN	(SELECT	SubmissionNumber, TransactionDate = MAX (TransactionDate)	FROM #temp_MasterLog WHERE OldPolicyType <> 'P' AND	DeletedFlag = 0	GROUP BY SubmissionNumber) q
			ON	p.SubmissionNumber = q.SubmissionNumber
			AND	p.TransactionDate <> q.TransactionDate
WHERE
	p.OldPolicyType <> 'P'
	AND	P.DeletedFlag = 0
	AND	p.SubmissionNumber	IN		(
																	SELECT	SubmissionNumber
																	FROM
																		(
																		SELECT	DISTINCT
																			SubmissionNumber, StatusCaption
																		FROM	
																			#temp_MasterLog 
																		WHERE
																			OldPolicyType <> 'P'
																			AND	DeletedFlag = 0
																		) m
																	GROUP BY SubmissionNumber 
																	HAVING COUNT (*) > 1
																	)
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 productlinesubtype, section, * from #temp_MasterLog  where submissionnumber like '16-10-01-044918%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
select submissionnumber, count (*) from #temp_Masterlog where isnull(masterpolicynumber, '') = '' and sourcesystemname like 'bhsi%' and deletedflag = 0 group by submissionnumber having count (*) >1
select * from #temp_Masterlog where isnull(masterpolicynumber, '') = '' and sourcesystemname like 'bhsi%' and submissionnumber ='16-12-02-049842'
select * from edw..bhsi_transaction where masterpolicynumber ='16-12-02-049842' and measurename like '%prem%'
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- DuckCreekSubmissionNumber
UPDATE
	p
SET
	DuckCreekSubmissionNumber = s.DuckCreekSubmissionNumber
FROM
	#temp_MasterLog p, EDW..v_DuckCreekSubmissionNumber s
WHERE
	p.PolicyId = s.PolicyId
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from #temp_MasterLog where MasterPolicyNumber = '42-PRP-302570-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- For first term Shred policies, Make DuckCreekSubmissionNumber as SubmissionNumber
UPDATE
	p
SET
	SubmissionNumber = p.DuckCreekSubmissionNumber
FROM
	#temp_MasterLog p
WHERE
	p.SourceSystemName = 'BHSI Policy'
	AND	RIGHT (p.MasterPolicyNumber, 3) = '-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Line of Insurance
UPDATE
	p
SET
	PolicyType =  CASE WHEN loi.LineOfInsuranceDesc = 'Unknown' THEN '' 
									WHEN loi.LineOfInsuranceDesc = 'MultiPeril' THEN 'Multi-Peril' 
									ELSE loi.LineOfInsuranceDesc 
							END
FROM
	#temp_MasterLog p
		JOIN YodilIDS_Warehouse.Policy.XrefPolicyLevels x
			ON	x.PolicyId = p.PolicyId
		LEFT JOIN YodilIDS_Warehouse.[Policy].LineOfInsurance loi
			on x.LineOfInsuranceID = loi.LineOfInsuranceID
WHERE
		x.EndDate ='9999-12-31'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Limit
UPDATE
	p
SET
	Currency = CASE WHEN	ISNULL (p.Currency, '') = '' THEN lmt.CurrencyCode ELSE p.Currency END
	, Limit = CONVERT (NUMERIC (19, 2), CASE	WHEN	SourceSystemName LIKE 'BHSI%' THEN ISNULL (CASE WHEN CONVERT (NUMERIC (19, 2), lmt.BHSIPerClaimLimit) > 1 THEN lmt.BHSIPerClaimLimit ELSE lmt.BHSIAggregateLimit END, lmt.BHSITotalLimitOfLiability)
																					WHEN	SourceSystemName = 'ODS' THEN	ISNULL (lmt.Limit, 0)
																					ELSE ISNULL (CASE WHEN CONVERT (NUMERIC (19, 2), lmt.BHSIPerClaimLimit) > 1 THEN lmt.BHSIPerClaimLimit ELSE lmt.BHSIAggregateLimit END, lmt.BHSITotalLimitOfLiability)
																		END)
	, LimitUSD = CONVERT (NUMERIC (19, 2), CASE	WHEN	SourceSystemName LIKE 'BHSI%' THEN	ISNULL (CASE WHEN CONVERT (NUMERIC (19, 2), lmt.BHSIPerClaimLimit) > 1 THEN lmt.BHSIPerClaimLimit ELSE lmt.BHSIAggregateLimit END, lmt.BHSITotalLimitOfLiability)
																						WHEN	SourceSystemName = 'ODS' THEN	ISNULL (lmt.Limit, 0)
																						ELSE ISNULL (CASE WHEN CONVERT (NUMERIC (19, 2), lmt.BHSIPerClaimLimit) > 1 THEN lmt.BHSIPerClaimLimit ELSE lmt.BHSIAggregateLimit END, lmt.BHSITotalLimitOfLiability)
																				END)
FROM
	#temp_MasterLog p
		JOIN EDW.dbo.v_Limit lmt
			ON		p.PolicyID = lmt.PolicyID
			AND	p.SourceSystemID = lmt.SourceSystemID
WHERE
	lmt.LimitDeductibleSirFlag = 'L'

-- Special Rule for CNP and LSB policies (email from Harinder on 20170619)
-- CNP
UPDATE
	p
SET
	Limit = CASE WHEN l.PerClaimLimit > 1 THEN l.PerClaimLimit 
							WHEN l.AggregateLimit > 1 THEN l.AggregateLimit 
							ELSE	NULL
				END
--select p.Coverage, p.PolicyType, p.MasterPolicyNumber, p.*
FROM
	#temp_MasterLog p, EDW.dbo.v_Coverage_limits l
WHERE
	p.PolicyID = l.PolicyId 
--	AND	p.Coverage = 'CNP'
	AND	p.PolicyType = 'CPPI'
	AND	l.CoverageCodeDesc = 'ContractorsProfessional'
--	and	p.MasterPolicyNumber = '42-CNP-303191-01'

-- LSB
UPDATE
	p
SET
	Limit = l.PerClaimLimit
--select p.Coverage, p.PolicyType, p.MasterPolicyNumber, p.*
FROM
	#temp_MasterLog p, EDW.dbo.v_Coverage_limits l
WHERE
	p.PolicyID = l.PolicyId 
--	AND	p.Coverage = 'LSB'
	AND	p.PolicyType = 'LifeSciencesBlended'
	AND	l.CoverageCodeDesc = 'PremisesOperations'

-- Update Limit to NULL when -1 and -2
UPDATE
	p
SET
	Limit = NULL
	, LimitUSD = NULL
--select *
FROM
	#temp_MasterLog p
WHERE
	p.Limit IN (-1.00, -2.00)
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select distinct limit  from #temp_MasterLog order by 1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- DeductibelInLocalCurrency, DeductibleInUSD
UPDATE
	p
SET
	DeductibleInLocalCurrency	= CASE	WHEN	SourceSystemName LIKE 'BHSI%'	THEN	lmt.DeductibleSIR
																		WHEN	SourceSystemName = 'ODS'	THEN	COALESCE (lmt.Deductible, lmt.DeductibleSIR)
																		ELSE	lmt.DeductibleSIR
															END
	, DeductibleInUSD	= CASE	WHEN	SourceSystemName LIKE 'BHSI%'	THEN	lmt.DeductibleSIR
														WHEN	SourceSystemName = 'ODS'	THEN	COALESCE (lmt.Deductible, lmt.DeductibleSIR)
														ELSE	lmt.DeductibleSIR
											END
FROM
	#temp_MasterLog p
		JOIN EDW.dbo.v_Limit lmt
			ON		p.PolicyID = lmt.PolicyID
			AND	p.SourceSystemID = lmt.SourceSystemID
WHERE
	lmt.LimitDeductibleSirFlag = 'D'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- SelfInsuredRetentionInLocalCurrency, SelfInsuredRetentionInUSD
UPDATE
	p
SET
	SelfInsuredRetentionInLocalCurrency	= CONVERT (NUMERIC (18, 2), CASE	WHEN SourceSystemName LIKE 'BHSI%' THEN COALESCE (lmt.SelfInsuredRetentionOfThePrimaryPolicy, lmt.SelfInsuredRetentionUmbrella, lmt.SelfInsuredRetention)
																																			WHEN SourceSystemName = 'ODS' THEN COALESCE (lmt.SIR, lmt.SelfInsuredRetentionOfThePrimaryPolicy, lmt.SelfInsuredRetentionUmbrella, lmt.SelfInsuredRetention)
																																			ELSE	lmt.SelfInsuredRetentionOfThePrimaryPolicy
																																END)
	, SelfInsuredRetentionInUSD	= CONVERT (NUMERIC (18, 2), CASE	WHEN SourceSystemName LIKE 'BHSI%' THEN COALESCE (lmt.SelfInsuredRetentionOfThePrimaryPolicy, lmt.SelfInsuredRetentionUmbrella, lmt.SelfInsuredRetention)
																															WHEN SourceSystemName = 'ODS' THEN COALESCE (lmt.SIR, lmt.SelfInsuredRetentionOfThePrimaryPolicy, lmt.SelfInsuredRetentionUmbrella, lmt.SelfInsuredRetention)
																															ELSE	lmt.SelfInsuredRetentionOfThePrimaryPolicy
																												END)
FROM
	#temp_MasterLog p
		JOIN EDW.dbo.v_Limit lmt
			ON		p.PolicyID = lmt.PolicyID
			AND	p.SourceSystemID = lmt.SourceSystemID
WHERE
	lmt.LimitDeductibleSirFlag = 'S'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from #temp_MasterLog where MasterPolicyNumber = '42-XPR-000009-05'
-- pr_Admin_Build_MasterLog
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from #temp_MasterLog where MasterPolicyNumber = '43-PRI-302320-01'
-- select top 100 * from v_Limit where PolicyNumber = '43-PRI-302320-01'
-- select top 100 * from v_Layer where PolicyNumber = '43-PRI-302320-01'
-- select * from #temp_MasterLog where MasterPolicyNumber = '42-PBR-303829-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- LayerLimit, AttachmentPoint
-- For Shred Non Property
UPDATE
	p
SET
	LayerofLimitInLocalCurrency = CONVERT (NUMERIC (19, 2), COALESCE (lmt.PartOfFullLayerLimit, lmt.BHSIPerClaimLimit, lmt.BHSIAggregateLimit))
	, LayerofLimitInUSD =	CONVERT (NUMERIC (19, 2), COALESCE (lmt.PartOfFullLayerLimit, lmt.BHSIPerClaimLimit, lmt.BHSIAggregateLimit))
	, AttachmentPoint = CONVERT (NUMERIC (19, 2), lmt.ExcessOfBHSIAttachmentPoint )
	, AttachmentPointUSD = CONVERT (NUMERIC (19, 2), lmt.ExcessOfBHSIAttachmentPoint) 
FROM
	#temp_MasterLog p, EDW.dbo.v_Limit lmt
WHERE
	p.PolicyID = lmt.PolicyID
--	AND	p.SourceSystemID = lmt.SourceSystemID
	AND	lmt.LimitDeductibleSirFlag = 'L'
	AND	p.ProductLine <> 'Property'
	AND	p.SourceSystemName LIKE 'BHSI%'

-- Shred Property
UPDATE
	p
SET
	LayerofLimitInLocalCurrency = CONVERT (NUMERIC (19, 2), COALESCE (layer.LayerLimit_OC, lmt.PartOfFullLayerLimit, lmt.BHSIPerClaimLimit, lmt.BHSIAggregateLimit))
	, LayerofLimitInUSD =	CONVERT (NUMERIC (19, 2), COALESCE (layer.LayerLimit_OC, lmt.PartOfFullLayerLimit, lmt.BHSIPerClaimLimit, lmt.BHSIAggregateLimit))
	, AttachmentPoint = CONVERT (NUMERIC (19, 2), COALESCE (ap.AttachmentPoint_OC, lmt.ExcessOfBHSIAttachmentPoint))
	, AttachmentPointUSD = CONVERT (NUMERIC (19, 2), COALESCE (ap.AttachmentPoint, lmt.ExcessOfBHSIAttachmentPoint))
FROM
	#temp_MasterLog p
		LEFT JOIN (SELECT PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemID, SourceSystemDesc, LayerLimit = SUM (LayerLimit), LayerLimit_OC = SUM (LayerLimit_OC) FROM EDW.dbo.v_Layer  GROUP BY PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemID, SourceSystemDesc) layer
			ON		p.PolicyId = layer.PolicyId 
		LEFT JOIN (SELECT PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemID, SourceSystemDesc, AttachmentPoint = MIN (AttachmentPoint), AttachmentPoint_OC = MIN (AttachmentPoint_OC) FROM EDW.dbo.v_Layer WHERE ISNULL (AttachmentPoint_OC, 0) <> 0 GROUP BY PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemID, SourceSystemDesc) ap
			ON		p.PolicyId = ap.PolicyId 
		LEFT JOIN EDW..v_Limit lmt
			ON	p.PolicyID = lmt.PolicyID
WHERE
	p.ProductLine = 'Property'
	AND	lmt.LimitDeductibleSirFlag = 'L'
	AND	p.SourceSystemName LIKE 'BHSI%'

-- select * from #temp_MasterLog where SubmissionNumber like '17-04-06-067464%'

-- ODS Policies and Quotes
UPDATE
	p
SET
	LayerofLimitInLocalCurrency = CONVERT (NUMERIC (19, 2), layer.LayerLimit_OC)
	, LayerofLimitInUSD =	CONVERT (NUMERIC (19, 2), layer.LayerLimit_OC)
	, AttachmentPoint = CONVERT (NUMERIC (19, 2), CASE WHEN ap.AttachmentPoint_OC IN (-1.00000000, -2.00000000) THEN NULL ELSE ap.AttachmentPoint_OC END)
	, AttachmentPointUSD = CONVERT (NUMERIC (19, 2), CASE WHEN ap.AttachmentPoint_OC IN (-1.00000000, -2.00000000) THEN NULL ELSE ap.AttachmentPoint_OC END)
FROM
	#temp_MasterLog p
		LEFT JOIN (SELECT PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemID, SourceSystemDesc, LayerLimit = SUM (LayerLimit), LayerLimit_OC = SUM (LayerLimit_OC) FROM EDW.dbo.v_Layer  GROUP BY PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemID, SourceSystemDesc) layer
			ON		p.PolicyId = layer.PolicyId 
		LEFT JOIN (SELECT PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemID, SourceSystemDesc, AttachmentPoint = MIN (AttachmentPoint), AttachmentPoint_OC = MIN (AttachmentPoint_OC) FROM EDW.dbo.v_Layer  GROUP BY PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemID, SourceSystemDesc) ap
			ON		p.PolicyID = ap.PolicyId 
WHERE
	p.SourceSystemName = 'ODS'
--	and p.SubmissionNumber like '17-04-03-067630%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from #temp_MasterLog where MasterPolicyNumber = '42-PBR-303829-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
-- select top 100 * from #temp_MasterLog where SubmissionNumber like '15-08-06-034776%'
select distinct limit from #temp_MasterLog order by 1
select ProcessDate, CurrentStatus, OriginalPremium, * from #temp_MasterLog where MasterPolicyNumber = '42-RLO-100208-03' order by 1, 2, 3
select PercentageofLayer, * from #temp_MasterLog where MasterPolicyNumber = '42-EPP-302650-01'
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PercentageOfLayer
-- First default 0.00 for Source Data
UPDATE
	p
SET
	PercentageOfLayer = 0.00
FROM
	#temp_MasterLog p

UPDATE
	p
SET
	PercentageofLayer = r.PercentageResponsible * 100
FROM
	#temp_MasterLog p, EDW.dbo.v_PctResponsible r
WHERE
	p.PolicyID = r.PolicyId 
	AND	p.SourceSystemDesc LIKE 'BHSI%'
	AND	p.ProductLine NOT IN ('Property')

UPDATE
	p
SET
	PercentageofLayer = p.Limit / p.LayerofLimitInLocalCurrency * 100
FROM
	#temp_MasterLog p
WHERE
	p.SourceSystemDesc LIKE 'BHSI%'
	AND	p.ProductLine  IN ('Property')

-- For ODS
UPDATE
	p
SET
	PercentageofLayer = r.PercentageResponsible * 100
FROM
	#temp_MasterLog p, EDW.dbo.v_PctResponsible r
WHERE
	p.PolicyID = r.PolicyId 
	AND	p.SourceSystemDesc = 'ODS'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select PercentageofLayer, Limit, * from #temp_MasterLog where MasterPolicyNumber like '%42-XSF-302536%'
-- pr_Admin_Build_MasterLog
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select distinct sourcesystemname, companypapernumber, companypaper from #temp_MasterLog order by 1, 2, 3
-- select * from edw..v_PolicyHolder where PolicyNumber = '47-SUR-300006-01' order by 3
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from #temp_MasterLog
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Policy Holder
UPDATE
	p
SET
--select distinct
	InsuredName = PolicyHolder.FullName
	, DBNumber = policyHolder.DBNumber
	, DBAName = CASE WHEN	p.SourceSystemPolicyId = 'SUR_SUBM' THEN '' ELSE  policyHolder.DBAName END
	, InsuredCountry = CASE	WHEN policyHolder.CountryName = 'UnitedStates' THEN 'USA' ELSE policyHolder.CountryName END
	, InsuredState = PolicyHolder.[StateName]
	, InsuredCity = PolicyHolder.[CityName]
	, InsuredMailingAddress1 = PolicyHolder.[StreetAddressLine1] 
	, InsuredZipcode = PolicyHolder.[PostalCode]
	, SourceSystemInsuredId = policyHolder.MainPartyUniqueIdentifier
	, AdvisenTicker = policyHolder.StockSymbol 
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_PolicyHolder policyHolder
			ON		p.PolicyId = policyHolder.PolicyId

-- InsuredState Get from CityStateZip
-- select top 100 * from BHSI_CityStateZip
UPDATE
	p
SET
	InsuredState = cs.StateName
FROM
	#temp_MasterLog p, EDW..BHSI_CityStateZip cs
WHERE
	p.InsuredZipCode = cs.ZipCode
	AND	ISNULL (p.InsuredState, '') = ''

-- InsuredCity Get from CityStateZip
UPDATE
	p
SET
	InsuredCity = cs.CityName
FROM
	#temp_MasterLog p, EDW..BHSI_CityStateZip cs
WHERE
	p.InsuredZipCode = cs.ZipCode
	AND	ISNULL (p.InsuredCity, '') = ''
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select insuredstate, count (*) from #temp_MasterLog group by insuredstate order by 1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select MasterPolicyNumber, PolicyId, InsuredName	, DBNumber, DBAName, InsuredCountry , InsuredState, InsuredCity, InsuredMailingAddress1, InsuredZipcode from #temp_MasterLog where MasterPolicyNumber like '%170005%'
-- select * from v_PolicyHolder where PolicyNumber = '42-RHC-170005-01'
-- select count (*) from #temp_MasterLog where isnull (InsuredState,'') <> '' -- 77386, 100987, 102127
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- InsuredContact
UPDATE
	p
SET
	InsuredContactPerson = insCon.FullName
	, InsuredContactPersonEmail = insCon.Email
	, InsuredContactPersonPhone = insCon.PrimaryPhone
	, InsuredContactPersonMobile = insCon.MobilePhone
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_InsuredContact insCon
			on p.PolicyID = insCon.PolicyID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from v_InsuredContact
-- select top 100 * from #temp_MasterLog where MasterPolicyNumber = '42-RHC-170022-01'
-- select top 100 productlinesubtype, section, * from #temp_MasterLog  where duckcreeksubmissionnumber = '15-01-03-002707'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- AdvisenUltimateParentCompanyName
UPDATE
	p
SET
	AdvisenUltimateParentCompanyName = up.FullName
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_UltimateParent up
			ON	p.PolicyId = up.PolicyId
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- AdvisenID
UPDATE
	p
SET
	AdvisenId = aID.AdvisenId
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_AdvisenID aID			
			ON	p.PolicyId = aID.PolicyId
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select advisenid, * from #temp_MasterLog where masterpolicynumber <> ''
-- select PolicyId, underwriter, * from #temp_MasterLog where masterpolicynumber = '47-EPC-303148-01'
-- select PolicyId, issuingOffice, * from #temp_MasterLog where SubmissionNumber like '14-09-06-015094%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- GUPAdvisenID
UPDATE
	p
SET
	GUPAdvisenId = aID.GUPAdvisenId
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_GUPAdvisenID aID
			ON	p.PolicyId = aId.PolicyId
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 1000 gupadvisenid, * from #temp_MasterLog where SourceSystemName like 'bhsi%' and gupadvisenid is not null
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Underwriter, IssuingUnderwriter, IssuingOffice
UPDATE
	p
SET
	Underwriter = Underwriter.Underwriter
FROM
	#temp_MasterLog p
	LEFT JOIN EDW.dbo.v_Underwriter underwriter
		ON	p.PolicyId = underwriter.PolicyId

UPDATE
	p
SET
	IssuingUnderwriter = underwriter.IssuingUnderwriter
FROM
	#temp_MasterLog p
	LEFT JOIN EDW.dbo.v_IssuingUnderwriter underwriter
		ON	p.PolicyId = underwriter.PolicyId

UPDATE
	p
SET
	IssuingOffice = CASE	WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Boston%' THEN '001 - Boston'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%New Y%' THEN '002 - New York'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%NY%' THEN '002 - New York'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Chicago%' THEN '003 - Chicago'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Los Angeles%' THEN '004 - Los Angeles'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%LA' THEN '004 - Los Angeles'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Toronto%' THEN '006 - Toronto'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Atlanta%' THEN '007 - Atlanta'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Houston%' THEN '008 - Houston'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%San Fran%' THEN '009 - San Francisco'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Singapore%' THEN '102 - Singapore'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%London%' THEN '401 - London'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Australia%' THEN '202 - Australia'
											WHEN	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Dusseldorf%' THEN '301 - Dusseldorf'
											ELSE	COALESCE (iuo.IssuingUnderwritingOffice, iur.IssuingUnderwritingRegion, uo.UnderwritingOffice, ur.UnderwritingRegion)
								END
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_IssuingUnderwritingOffice iuo
			ON	p.PolicyId = iuo.PolicyId
		LEFT JOIN EDW.dbo.v_IssuingUnderwritingRegion iur
			ON	p.PolicyId = iur.PolicyId
		LEFT JOIN EDW.dbo.v_UnderwritingOffice uo
			ON	p.PolicyId = uo.PolicyId
		LEFT JOIN EDW.dbo.v_UnderwritingRegion ur
			ON	p.PolicyId = ur.PolicyId
--where p.MasterPolicyNumber = '47-EPC-303148-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from v_UnderwritingRegion where PolicyNumber in ('42-RHC-170005-01', '42-RHC-170000-01')
-- select * from v_BrancOffice where PolicyNumber in ('42-RHC-170005-01', '42-RHC-170000-01')
-- select Underwriter, IssuingUnderwriter, IssuingOffice, * from #temp_MasterLog where MasterPolicyNumber = '42-RHC-170000-01'
-- select distinct issuingoffice from #temp_MasterLog 
-- select top 100 * from v_BrokerCode where PolicyNumber = '13-09-04-002469-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- BrokerCode
UPDATE
	p
SET
	BrokerCode = bc.BrokerCode
FROM
	#temp_MasterLog p
	LEFT JOIN EDW.dbo.v_BrokerCode bc
		/* IT 20160608
		ON		p.OldMasterPolicyNumber = bc.MasterPolicyNumber
		AND	p.OldPolicyNumber = bc.PolicyNumber
		AND	p.SourceSystemID = bc.SourceSystemID
		*/
		on p.PolicyID = bc.PolicyID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from v_BrokerCode where PolicyNumber = '42-PSC-302734-01'
-- select BrokerCode, * from #temp_MasterLog where MasterPolicyNumber like '%42-PSC-302734-01%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- AlternativeAddress1
-- select top 100 * from EDW.dbo.v_AppointmentStatus
UPDATE
	p
SET
	AlternativeAddress1 = app.AppointmentStatus
FROM
	#temp_MasterLog p
	LEFT JOIN EDW.dbo.v_AppointmentStatus app
		ON	p.PolicyID = app.PolicyId 
		--ON		p.OldMasterPolicyNumber = app.MasterPolicyNumber
		--AND	p.OldPolicyNumber = app.PolicyNumber
		--AND	p.SourceSystemID = app.SourceSystemID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 BrokerName, BrokerCode, BrokerCountry, BrokerState, BrokerCity, * from #temp_MasterLog where SubmissionNumber = '17-02-06-066027-01'
-- select top 100 BrokerName, BrokerCode, BrokerCountry, BrokerState, BrokerCity, * from #temp_MasterLog where MasterPolicyNumber = '42-CNP-304080-01'
-- select top 100 * from v_Producer where PolicyNumber = '47-SUR-300013-01' order by 3, 2
-- select top 100 * from v_appointmentstatus
/*
select distinct brokercountry from #temp_MasterLog order by 1
select distinct brokerstate from #temp_MasterLog order by 1
select distinct brokercity from #temp_MasterLog order by 1
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Broker/Producer
-- select top 100 * from v_Producer
UPDATE
	p
SET
	BrokerName = pd.FullName
	, BrokerContactPersonStreetAddress = pd.StreetAddressLine1
	, BrokerCity = CASE WHEN LEN (pd.CityName) <= 0 THEN NULL
										ELSE LTRIM (RTRIM (pd.[CityName])) + CASE WHEN LEN (p.BrokerCode) >= 18 THEN '-' + SUBSTRING (p.BrokerCode, 15, 4) ELSE '' END
							END
	, BrokerState = CASE	WHEN LEN (pd.StateName) <= 0 THEN NULL
											ELSE pd.StateName + CASE WHEN LEN (p.BrokerCode) >= 13 THEN '-' + SUBSTRING (p.BrokerCode, 11, 3) ELSE '' END 
								END
	, BrokerContactPersonZipCode = pd.PostalCode
--	, BrokerCountry = CASE WHEN LEN (p.BrokerCode) >= 9 THEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) ELSE NULL END + ' - ' + pd.CountryName
	, BrokerCountry = CASE	WHEN LEN (p.BrokerCode) >= 9 
													THEN CASE	WHEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) = '999' THEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) + ' - Not Available'
																			WHEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) = '998' THEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) + ' - To Be Entered'
																			ELSE	RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) + ' - ' + pd.CountryName
																END
													ELSE pd.CountryName
										END
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_Producer pd
			ON		p.PolicyId = pd.PolicyId

-- Additional Update PolicyNumber - MasterPolicyNumber for NULL Brokers
UPDATE
	p
SET
	BrokerName = pd.FullName
	, BrokerContactPersonStreetAddress = pd.StreetAddressLine1
	, BrokerCity = CASE WHEN LEN (pd.CityName) <= 0 THEN NULL
										ELSE	pd.[CityName] + CASE WHEN LEN (p.BrokerCode) >= 18 THEN '-' + SUBSTRING (p.BrokerCode, 15, 4) ELSE '' END
							END
	, BrokerState = CASE	WHEN LEN (pd.StateName) <= 0 THEN NULL
											ELSE pd.StateName + CASE WHEN LEN (p.BrokerCode) >= 13 THEN '-' + SUBSTRING (p.BrokerCode, 11, 3) ELSE '' END 
								END
	, BrokerContactPersonZipCode = pd.PostalCode
	, BrokerCountry = CASE WHEN LEN (p.BrokerCode) >= 9 THEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) ELSE NULL END + ' - ' + pd.CountryName
FROM
	#temp_MasterLog p
	LEFT JOIN EDW.dbo.v_Producer pd
		on p.PolicyID = pd.PolicyID
WHERE
	ISNULL (p.BrokerName, '') = ''

-- Broker State capturing data from BrokerCityState
UPDATE
	p
SET
--select distinct 
	BrokerState = CASE	WHEN LEN (pd.BrokerState) <= 0 THEN NULL
											ELSE	pd.[BrokerState] + '-' + CASE WHEN LEN (p.BrokerCode) >= 5 THEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 5), 3) ELSE NULL END
								END
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.BHSI_BrokerCityState pd
			ON		p.BrokerCode = pd.BrokerFullCode
WHERE
	ISNULL (p.BrokerState, '') = ''

-- Broker Country capturing data from BrokerCityState
UPDATE
	p
SET
--select distinct
	BrokerCountry = CASE WHEN LEN (p.BrokerCode) >= 9 THEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) ELSE NULL END + ' - ' + pd.BrokerCountry
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.BHSI_BrokerCityState pd
			ON		p.BrokerCode = pd.BrokerFullCode
WHERE
	ISNULL (p.BrokerCountry , '') = ''
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select BrokerName, BrokerContactPersonStreetAddress, brokercity, brokerState, BrokerContactPersonZipCode, BrokerCountry, BrokerCode, * from #temp_MasterLog where MasterPolicyNumber = '42-RHC-170011-01'
-- select brokercity, brokerState, BrokerCountry, BrokerCode, * from #temp_MasterLog where submissionnumber = '13-10-04-002666-01'
-- select ProcessDate, CurrentStatus, OriginalPremium, * from #temp_MasterLog where MasterPolicyNumber = '42-RLO-100208-03' order by 1, 2, 3
-- select distinct BrokerCountry from #temp_MasterLog order by 1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- BrokerContact
--select top 100 * from v_brokercontact 
UPDATE
	p
SET
	BrokerContactPerson = brokerContact.FullName 
--	, BrokerContactPersonStreetAddress = BrokerContact.[StreetAddressLine1] 
--	, BrokerContactPersonZipCode = BrokerContact.[PostalCode]
	, BrokerContactPersonEmail = brokerContact.Email
	, BrokerContactPersonNumber = brokerContact.PrimaryPhone
	, BrokerContactPersonMobile = brokerContact.MobilePhone
FROM
	#temp_MasterLog p
	LEFT JOIN EDW.dbo.v_BrokerContact brokerContact
		on p.PolicyID = brokerContact.PolicyID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from v_BrokerContact where PolicyNumber = '42-RHC-170011-01'
-- select BrokerContactPerson, BrokerContactPersonEmail, BrokerContactPersonNumber, BrokerContactPersonMobile, * from #temp_MasterLog where masterpolicynumber = '42-RHC-170011-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- BrokerType
UPDATE
	p
SET
	BrokerType = CASE	WHEN	bt.BrokerType IN ('Retail', 'Retailer') THEN	'Retailer'
										WHEN	bt.BrokerType IN ('Wholesale', 'Wholesaler') THEN	'Wholesaler'
										ELSE	bt.BrokerType
								END
FROM
	#temp_MasterLog p
	LEFT JOIN EDW.dbo.v_BrokerType bt
		ON	p.PolicyID = bt.PolicyID 
		--ON		p.OldMasterPolicyNumber = bt.MasterPolicyNumber
		--AND	p.OldPolicyNumber = bt.PolicyNumber
		--AND	p.SourceSystemID = bt.SourceSystemID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from v_brokertype
-- select brokertype, brokercode, * from #temp_MasterLog where MasterPolicyNumber = '42-PSC-302734-01'
-- select distinct sourcesystemname, currentstatus from #temp_Masterlog order by 1, 2
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from v_audit_riskFactor where policyNumber = '42-PRP-301025-01'
-- select * from #temp_MasterLog where masterpolicyNumber = '42-PRP-301025-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Audit RiskFactors
UPDATE
	p
SET
	NAICCode		= arf.NAICSCode
	, NAICTitle			= arf.NAICSCodeDesc
	, ClassName		= arf.ClassType
	, ClassCode		= arf.StatisticalPlanCode
	, ISOCode			= arf.ISOCode
	, Affiliation			= arf.Affiliation
	, AdvisenSicPrimaryNumeric = arf.SicCode
	, AdvisenSicPrimaryNumericDesc = arf.SicCodeDesc
	, AdvisenRevenue = arf.Revenue
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_Audit_RiskFactor arf
			on p.PolicyID = arf.PolicyID
WHERE
	arf.RiskFactorType = 'PolicyRF'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CompanyPaper for ODS Data
UPDATE
	p
SET
	CompanyPaper = arf.CompanyPaper 
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_Audit_RiskFactor arf
			on p.PolicyID = arf.PolicyID
WHERE
	arf.RiskFactorType = 'PolicyRF'
	AND	p.SourceSystemName IN ('ODS')
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from v_Audit_RiskFactor where policynumber in ('42-RHC-170003-01', '42-RHC-170008-01')
-- select ReasonCode, NaicCode, NaicTitle, ClassName, ClassCode, * from #temp_MasterLog where MasterPolicyNumber in ('43-XMC-302776-01')
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Get longer NaicsDesc from Frozen table
-- Shred Policy
UPDATE
	p
SET
	NaicTitle = n.NaicsDesc
FROM
	#temp_MasterLog p, EDW.dbo.BHSI_NaicsLongDesc n
WHERE
	p.MasterPolicyNumber = n.PolicyNumber 
	AND	p.NaicCode = n.NaicsCode
	AND	p.NAICTitle <> n.NaicsDesc 
	AND	p.SourceSystemDesc LIKE 'BHSI%'

-- Shred Quote/ Sub
UPDATE
	p
SET
	NaicTitle = n.NaicsDesc
FROM
	#temp_MasterLog p, EDW.dbo.BHSI_NaicsLongDesc n
WHERE
	p.SubmissionNumber = n.PolicyNumber 
	AND	ISNULL (p.MasterPolicyNumber, '') = ''
	AND	p.NaicCode = n.NaicsCode
	AND	p.NAICTitle <> n.NaicsDesc 
	AND	p.SourceSystemDesc LIKE 'BHSI%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select naiccode, naictitle, * from #temp_MasterLog where MasterPolicyNumber = '47-MSL-000039-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Total Insured
UPDATE
	p
SET
	TotalInsuredValue = totIns.LimitValue
	, TotalInsuredValueInUSD = totIns.LimitValue
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_TotalInsured totIns
			/* IT 20160608
			ON		p.OldMasterPolicyNumber = totIns.MasterPolicyNumber
			AND	p.OldPolicyNumber = totIns.PolicyNumber
			AND		p.SourceSystemID = totIns.SourceSystemID
		*/ 
		on p.PolicyID = totIns.PolicyID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select BrancOffice, PolicyId, * from #temp_MasterLog where MasterPolicyNumber = '42-EMC-302445-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- BrancOffice
UPDATE
	p
SET
	BrancOffice = COALESCE (uo.UnderwritingOfficeCode, ur.UnderwritingRegionCode) + ' - ' + 
									 CASE	WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Boston%' THEN 'Boston'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%New Y%' THEN 'New York'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%NY%' THEN 'New York'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Chicago%' THEN 'Chicago'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Los Angeles%' THEN 'Los Angeles'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE 'LA%' THEN 'Los Angeles'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Toronto%' THEN 'Toronto'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Atlanta%' THEN 'Atlanta'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Houston%' THEN 'Houston'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%San Fran%' THEN 'San Francisco'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%Australia%' THEN 'Australia'
												WHEN	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion) LIKE '%New Zealand%' THEN 'New Zealand'
												ELSE	COALESCE (uo.UnderwritingOffice, ur.UnderwritingRegion)
									END
	, Region = COALESCE (uo.Region, ur.Region)
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_UnderwritingOffice uo
			ON p.PolicyID = uo.PolicyID
		LEFT JOIN EDW.dbo.v_UnderwritingRegion ur
			ON p.PolicyID = ur.PolicyID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select distinct brancoffice, region from #temp_MasterLog
-- select * from #temp_MasterLog where brancoffice = '202 - Los Angeles'
-- select brancoffice, *  from #temp_MasterLog where MasterPolicyNumber in ('42-XPR-000235-03')
-- select distinct underwritingRegion from edw..v_underwritingRegion order by 1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Project Name and Address
UPDATE
	p
SET
	ProjectName = pj.FullName
	, ProjectStreetAddress = pj.StreetAddressLine1
	, ProjectCountry = pj.CountryName
	, ProjectState = pj.StateName
	, ProjectCity = pj.CityName
	, Latitude = pj.Latitude
	, Longitude = pj.Longitude
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_Project pj
			ON		p.PolicyId = pj.PolicyId
			--ON		p.OldMasterPolicyNumber = pj.MasterPolicyNumber
			--AND	p.OldPolicyNumber = pj.PolicyNumber
			--AND	p.SourceSystemID = pj.SourceSystemID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--select top 100 OldMasterPolicyNumber, OldPolicyNumber, PolicyId, Policykey, ProjectName, BidSituation, GeneralContractor, MasterPolicyNumber, PremMasterPolicyNumber, * from #temp_MasterLog where MasterPolicyNumber like '%40-SUR-300002-01%' order by 1
--select top 100 * from v_Project where PolicyNumber = '40-SUR-300002-01' and MasterPolicyNumber like '14-08-06-015088%' order by 1
--select top 100 PolicyId, Policykey, ProjectName, BidSituation, GeneralContractor, MasterPolicyNumber, PremMasterPolicyNumber, * from #temp_MasterLog where isnull (ProjectName, '') <> ''
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Project Extra Data
UPDATE
	p
SET
	 BidSituation = pEd.BidSituation
	, GeneralContractor = pEd.GeneralContractorName
	, ProjectOwnerName = pEd.ProjectOwnerName
	, ProjectType = pEd.ProjectType
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_ProjectExtraData pEd
			ON	p.PolicyID = ped.PolicyID 
		--	ON		p.OldMasterPolicyNumber = pEd.MasterPolicyNumber
		--	AND	p.OldPolicyNumber = pEd.PolicyNumber
		--AND		p.SourceSystemID = pEd.SourceSystemID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--select distinct sourcesystemname, BidSituation from #temp_MasterLog order by 1
-- select top 100 * from v_audit_riskfactor where policynumber = '42-XMC-170015-01'
-- select * from #temp_MasterLog where MasterPolicyNumber = '47-SUR-300006-01' order by submissionnumber
-- select * from v_retailbroker where policynumber = '40-SUR-300012-01'
-- SELECT * FROM EDW..BHSI_CityStateZip
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- RetailBroker
UPDATE
	p
SET
--select rb.CountryName, lkup_Cn.CountryName,
	RetailBroker					= rb.FullName
	--, RetailBrokerCountry	= CASE	WHEN rb.CountryName IS NULL THEN NULL
	--														ELSE	CASE	WHEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) = '999' THEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) + ' - Not Available'
	--																			WHEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) = '998' THEN RIGHT (LEFT (p.BrokerCode, LEN (p.BrokerCode) - 9), 3) + ' - To Be Entered'
	--																			ELSE	lkup_Cn.LegacyCountryCode + ' - ' + rb.CountryName
	--																END																												
	--										END
	, RetailBrokerCountry	= CASE	WHEN rb.CountryName IS NULL THEN NULL
															WHEN rb.CountryName = 'TO BE ENTERED' THEN '998 - ' + rb.CountryName
															WHEN rb.CountryName = 'Not Available' THEN '999 - ' + rb.CountryName
															WHEN rb.CountryName = 'Unknown' THEN '000 - ' + rb.CountryName
															ELSE		lkup_Cn.LegacyCountryCode + ' - ' + rb.CountryName
											END
	, RetailBrokerState		= CASE	WHEN rb.StateName IS NULL THEN NULL
															WHEN rb.StateName = 'TO BE ENTERED' THEN rb.StateName + ' - 998'
															WHEN rb.StateName = 'Not Available' THEN rb.StateName + ' - 999'
--															ELSE	rb.StateName + ' - ' + s.LegacyStateCode
															ELSE		rb.StateName + CASE WHEN LEN (p.BrokerCode) >= 13 THEN ' - ' + lkup_St.LegacyStateCode ELSE '' END 
												END
	, RetailBrokerCity			= CASE	WHEN rb.CityName IS NULL THEN NULL
															WHEN rb.CityName = 'TO BE ENTERED' THEN rb.CityName + '-9998'
															WHEN rb.CityName = 'Not Available' THEN rb.CityName + '-9999'
--															ELSE	rb.CityName + ' - ' + cty.LegacyCityCode
															ELSE		rb.CityName + CASE WHEN LEN (p.BrokerCode) >= 18 THEN '-' + lkup_Ct.LegacyCityCode ELSE '' END
												END
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_RetailBroker rb
			ON	p.PolicyID = rb.PolicyID
		LEFT JOIN (SELECT DISTINCT CountryName, LegacyCountryCode FROM EDW..BHSI_CityStateZip) lkup_Cn
			ON	ISNULL (LTRIM (RTRIM (rb.CountryName)), 'USA') = LTRIM (RTRIM (lkup_Cn.CountryName))
		LEFT JOIN (SELECT DISTINCT CountryName, LegacyCountryCode, StateName, StateAbbreviationCode, LegacyStateCode FROM EDW..BHSI_CityStateZip) lkup_St
			ON	ISNULL (LTRIM (RTRIM (rb.CountryName)), 'USA') = LTRIM (RTRIM (lkup_St.CountryName))
			AND	LTRIM (RTRIM (rb.StateName)) = LTRIM (RTRIM (lkup_St.StateName))
		LEFT JOIN (SELECT DISTINCT CountryName, LegacyCountryCode, StateName, StateAbbreviationCode, LegacyStateCode, CityName, LegacyCityCode FROM EDW..BHSI_CityStateZip) lkup_Ct
			ON	ISNULL (LTRIM (RTRIM (rb.CountryName)), 'USA') = LTRIM (RTRIM (lkup_Ct.CountryName))
			AND	LTRIM (RTRIM (rb.StateName)) = LTRIM (RTRIM (lkup_Ct.StateName))
			AND	LTRIM (RTRIM (rb.CityName)) = LTRIM (RTRIM (lkup_Ct.CityName))
--where
--	p.submissionnumber like '%15-12-06-043799-83%'

-- Now Update the Frozen data
-- Policy
UPDATE
	p
SET
	RetailBroker					= rb.RetailBrokerName
	, RetailBrokerCountry	= rb.RetailBrokerCountry
	, RetailBrokerState		= rb.RetailBrokerState
	, RetailBrokerCity			= rb.RetailBrokerCity
FROM
	#temp_MasterLog p, EDW..BHSI_RetailBroker_Frozen rb
WHERE
	p.MasterPolicyNumber = rb.MasterPolicyNumber
	AND	p.SourceSystemName LIKE 'BHSI Policy%'
	AND	ISNULL (p.MasterPolicyNumber, '') <> ''

-- Quote/Submission
UPDATE
	p
SET
	RetailBroker					= rb.RetailBrokerName
	, RetailBrokerCountry	= rb.RetailBrokerCountry
	, RetailBrokerState		= rb.RetailBrokerState
	, RetailBrokerCity			= rb.RetailBrokerCity
FROM
	#temp_MasterLog p, EDW..BHSI_RetailBroker_Frozen rb
WHERE
	p.SubmissionNumber = LEFT (rb.SubmissionNumber_DC, LEN (rb.SubmissionNumber_DC) - 3)
	AND	p.SourceSystemName LIKE 'BHSI Quote%'
	AND	ISNULL (p.MasterPolicyNumber, '') = ''
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from v_RetailBroker where PolicyNumber = '42-RHC-170008-01'
-- select CurrentStatus, OriginalPremium, ProcessDate, BindDate, BrokerCountry, * from #temp_MasterLog where SubmissionNumber = '42-XPR-301192-01' order by EffectiveDate, ActualProcessDate
-- select ProcessDate, CurrentStatus, OriginalPremium, * from #temp_MasterLog where MasterPolicyNumber = '42-RLO-100208-03' order by 1, 2, 3
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CabCompanies
/*
-- BHSI
UPDATE
	p
SET
	CabCompanies = c.CabCompanies
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_CabCompanies c
			ON		p.OldMasterPolicyNumber = c.MasterPolicyNumber
			AND	p.OldPolicyNumber = c.PolicyNumber
		AND		p.SourceSystemID = c.SourceSystemID
WHERE
	p.SourceSystemName LIKE '%BHSI%'
*/

-- ODS
UPDATE
	p
SET
	CabCompanies = c.CabCompanies
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_Audit_RiskFactor c
			ON	p.PolicyID = c.PolicyID
WHERE
	p.SourceSystemName LIKE '%ODS%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select distinct sourcesystemname, CabCompanies from #temp_MasterLog order by 1
-- select top 100 * from v_Audit_RiskFactor
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- OfacReport
UPDATE
	p
SET
	OFRCReport = rf.OFRCAdverseReport
FROM
	#temp_MasterLog p, EDW..v_Audit_RiskFactor rf
WHERE
	p.PolicyID = rf.PolicyID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from #temp_MasterLog where MasterPolicyNumber = '47-SUR-300053-01'
-- select * from #temp_MasterLog where SubmissionNumber = '14-10-06-015872-01'
-- select * from code_converter_2_20170703 where productline = 'surety'
-- update #temp_MasterLog set Orig_ProfitCode = ProfitCode
-- select * into ##tempCode from #temp_MasterLog
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Email Unmapped Codes (SubType, Section and ProfitCode)
-- First add leading zeros to Subtype, Section and ProfitCode
UPDATE
	p
SET
	ProductLineSubType	= CASE	WHEN	LEN (p.ProductLineSubType) < 4 THEN 	RIGHT ('0000' + p.ProductLineSubType, 4) ELSE p.ProductLineSubType END
	, Section							= CASE	WHEN	LEN (p.Section) < 6 THEN RIGHT ('000000' + p.Section, 6) ELSE p.Section END
	, ProfitCode					= CASE	WHEN	LEN (p.ProfitCode) < 7 THEN RIGHT ('0000000' + ProfitCode, 7)	ELSE p.ProfitCode END
FROM
	#temp_MasterLog p

IF	OBJECT_ID ('tempDB..#temp_CodeConverter') IS NOT NULL	DROP	TABLE #temp_CodeConverter
SELECT
	ProductLine = CASE WHEN ProductLine IN ('Exec & Prof', 'E&P') THEN 'Exec & Prof'
										WHEN ProductLine IN ('Program', 'Programs') THEN 'Program'
										WHEN ProductLine IN ('Medical Stop Loss', 'Stop Loss') THEN 'Medical Stop Loss'
										WHEN ProductLine IN ('Small Commercial', 'Small Commercial Lines') THEN 'Small Commercial'
										ELSE	ProductLine
								END
	, [Type]
	, Code_Val
	, Code_Desc
INTO
	#temp_CodeConverter
FROM
	EDW..Code_Converter_2
-- select * from #temp_CodeConverter

IF	OBJECT_ID ('tempDB..##temp_MissingMapping') IS NOT NULL	DROP	TABLE ##temp_MissingMapping
CREATE	TABLE ##temp_MissingMapping (
	CodeType				VARCHAR (20)
	, ProductLine			VARCHAR (20)
	, Code						VARCHAR (20)
)
INSERT INTO
	##temp_MissingMapping (CodeType, ProductLine, Code)
SELECT DISTINCT
	'ProductLineSubtype', p.ProductLine, p.ProductLineSubtype
FROM
	#temp_MasterLog p
		LEFT JOIN (SELECT DISTINCT ProductLine, Code_Val FROM #temp_CodeConverter WHERE [Type] = 'ProductLineSubtype') cc
			ON	p.ProductLine = cc.ProductLine
			AND	LEFT (p.ProductLineSubtype, 4) = cc.Code_Val
WHERE
	cc.ProductLine IS NULL
	AND	cc.Code_Val IS NULL
UNION ALL
SELECT DISTINCT
	'SectionCode', p.ProductLine, p.Section
FROM
	#temp_MasterLog p
		LEFT JOIN (SELECT DISTINCT ProductLine, Code_Val FROM #temp_CodeConverter WHERE [Type] = 'SectionCode') cc
			ON	p.ProductLine = cc.ProductLine
			AND	LEFT (p.Section, 5) = cc.Code_Val
WHERE
	cc.ProductLine IS NULL
	AND	cc.Code_Val IS NULL
UNION
SELECT DISTINCT
	'ProfitCode', p.ProductLine, p.ProfitCode
FROM
	#temp_MasterLog p
		LEFT JOIN (SELECT DISTINCT ProductLine, Code_Val FROM #temp_CodeConverter WHERE [Type] = 'ProfitCode') cc
			ON	p.ProductLine = cc.ProductLine
			AND	LEFT (p.ProfitCode, 6) = cc.Code_Val
WHERE
	cc.ProductLine IS NULL
	AND	cc.Code_Val IS NULL
-- select * from ##temp_MissingMapping

---- Send Email Notification
--IF	(SELECT COUNT (*) FROM ##temp_MissingMapping)> 0
--BEGIN
--	EXEC msdb.dbo.sp_send_dbmail  
--		@profile_name = 'O365 SMTP Profile',  
--		@recipients = 'Shaikh.Rahman@bhspecialty.com',  
----		@recipients = 'EDW_Support@bhspecialty.com',  
--		@subject = 'Mapping for ProductLineSubType/Section/ProfitCode is Missing. Please Take Action!' ,  
--		@query				= N'SELECT CodeType = LEFT (CodeType, 20), ProductLine = LEFT (ProductLine, 20), Code = LEFT (Code, 10) from ##temp_MissingMapping ORDER BY 1, 2, 3';
--END
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from ##temp_MIssingMapping
-- pr_Admin_Build_MasterLog
-- select OriginalPremium, * from #temp_MasterLog where PolicyStatus = 'Bound' and StatusCaption = 'Add. Bound Coverage/layer' and TransactionType = 'Add. Bound Coverage/layer' and SubmissionNumber = '17-01-03-065120-01'
-- select distinct ProductLine, ProductLineSubType, Section, ProfitCode from #temp_MasterLog 
-- select ProductLine, ProductLineSubType, Section, ProfitCode, * from #temp_MasterLog where ProfitCode = '204006'
--select top 100 * from Code_Converter where code_val = '204006'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Product Line Sub Type
UPDATE
	p
SET
	ProductLineSubType = ISNULL (cc.Code_Val + '-' + cc.Code_Desc, '')
FROM
	#temp_MasterLog p, #temp_CodeConverter cc
WHERE
	p.ProductLineSubType = cc.Code_Val
	AND	cc.[Type] = 'ProductLineSubType'
	AND	p.ProductLine = cc.ProductLine 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 productlinesubtype, section, * from #temp_MasterLog  where masterpolicynumber = '47-Not Applicable-NT/APP-01'
-- select top 100 productlinesubtype, section, * from #temp_MasterLog  where masterpolicynumber = '42-EPP-302746-01'
-- pr_Admin_Build_MasterLog
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Section
UPDATE
	p
SET
	Section = ISNULL (cc.Code_Val + '-' + cc.Code_Desc , '')
FROM
	#temp_MasterLog p, #temp_CodeConverter cc
WHERE
	p.Section = cc.Code_Val
	AND	cc.[Type] = 'SectionCode'
	AND	p.ProductLine = cc.ProductLine 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select profitcode, section, productlinesubtype, * from #temp_MasterLog where masterpolicynumber = '42-XMC-301322-01'
-- select profitcode, section, productlinesubtype, * from #temp_MasterLog where SubmissionNumber like '%14-10-06-015872-01%' 
-- select len (profitcode) from #temp_MasterLog where SubmissionNumber like '%14-10-06-015872-01%' 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Profit Code
UPDATE
	p
SET
	ProfitCode = ISNULL (cc.Code_Val + '-' + cc.Code_Desc, '')
FROM
	#temp_MasterLog p, #temp_CodeConverter cc
WHERE
	p.ProfitCode = cc.Code_Val
	AND	cc.[Type] = 'ProfitCode'
	AND	p.ProductLine = cc.ProductLine 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from #temp_MasterLog where MasterPolicyNumber in ('42-XPR-302799-01')
--select distinct policystatus from #temp_MasterLog order by 1
--select distinct statuscaption from #temp_MasterLog order by 1
--select sum (grosspremiumusd) from #temp_MasterLog order by 1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- exec pr_Admin_Build_MasterLog
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Bind Date
UPDATE
	p
SET
	BindDate = ISNULL (bd.BindDate, p.BindDate)
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_BindDate bd
			ON	p.PolicyKey = bd.PolicyKey
--			p.PolicyID = bd.PolicyID
		--	ON		p.OldMasterPolicyNumber = bd.MasterPolicyNumber
		--	AND	p.OldPolicyNumber = bd.PolicyNumber
		--AND		p.SourceSystemID = bd.SourceSystemID
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select policynumber, masterpolicynumber, count (*) from v_BindDate group by policynumber, masterpolicynumber having count (*) > 1
-- select * from v_BindDate where policynumber = '42-XPR-000041-01'
-- select binddate, *  from #temp_MasterLog where MasterPolicyNumber in ('42-UHC-170004-01', '42-RHC-170005-01', '42-RHC-170000-01')
-- select top 100 * from v_BindDate where PolicyNumber = '42-RHC-170005-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ByBerkSIFromBroker
-- BHSI
UPDATE
	p
SET
	ByBerkSIFromBroker = bb.ByBerkSIFromBroker
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_ByBerkSIFromBroker bb
			ON		p.OldMasterPolicyNumber = bb.MasterPolicyNumber
			AND	p.OldPolicyNumber = bb.PolicyNumber
			AND	p.SourceSystemID = bb.SourceSystemID
WHERE
	p.SourceSystemName LIKE '%BHSI%'

-- ByIndiaFromBerkSI
UPDATE
	p
SET
	ByIndiaFromBerkSI = bb.ByIndiaFromBerkSI
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_ByIndiaFromBerkSI bb
			ON		p.OldMasterPolicyNumber = bb.MasterPolicyNumber
			AND	p.OldPolicyNumber = bb.PolicyNumber
			AND	p.SourceSystemID = bb.SourceSystemID
WHERE
	p.SourceSystemName LIKE '%BHSI%'

-- select ByBerkSIFromBroker, ByIndiaFromBerkSi, * from #temp_MasterLog where SubmissionNumber = '17-01-02-065267-01'
-- ODS
UPDATE
	p
SET
	ByBerkSIFromBroker = CONVERT (VARCHAR (10), CONVERT (DATETIME, LEFT (bb.ByBerkSIFromBroker, 12)), 120)
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_Audit_RiskFactor bb
			ON	p.PolicyID = bb.PolicyID
WHERE
	p.SourceSystemName LIKE '%ODS%'

-- ByIndiaFromBerkSI
UPDATE
	p
SET
	ByIndiaFromBerkSI = CONVERT (VARCHAR (10), CONVERT (DATETIME, LEFT (bb.ByIndiaFromBerkSI, 12)), 120)
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_Audit_RiskFactor bb
			ON	p.PolicyID = bb.PolicyID
WHERE
	p.SourceSystemName LIKE '%ODS%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from v_Audit_RiskFactor where PolicyNumber = '42-RHC-170002-01'
-- select ByIndiaFromBerkSI, ByBerkSIFromBroker, * from #temp_MasterLog where MasterPolicyNumber = '42-RHC-170002-01'
-- select ByIndiaFromBerkSI, ByBerkSIFromBroker, * from #temp_MasterLog where sourcesystemname = 'bhsi' 
-- select ProcessDate, CurrentStatus, OriginalPremium, * from #temp_MasterLog where MasterPolicyNumber = '42-RLO-100208-03' order by 1, 2, 3
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
EXEC pr_Admin_Build_MasterLog
select distinct Sourcesystemname,  CurrentStatus, PolicyStatus, StatusCaption, TransactionType from #temp_MasterLog where MasterPolicyNumber = '43-LDA-150394-01'
select PolicyId, PolicyLevelsCompoundId, date1, * from #temp_MasterLog where MasterPolicyNumber = '42-EPT-303353-01'
select * from edw..v_shreddate1 where policynumber = '42-EPT-303353-01'
select * from v_ODSExtraData where PolicyNumber = '43-LDA-150394-01'
select top 100 MasterPolicyNumber, SubmissionNumber, CurrentStatus, OriginalPremium, * from #temp_MasterLog where PolicyStatus = 'InForce' and StatusCaption = 'In force' and TransactionType like 'New%' and MasterPolicyNumber <> ''
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Shred Date1
UPDATE
	p
SET
	Date1 = d.Policy_TransactionDateTime
FROM
	#temp_MasterLog p, EDW..v_ShredDate1 d
WHERE
	p.OldMasterPolicyNumber = d.MasterPolicyNumber
	AND	p.OldPolicyNumber = d.PolicyNumber
	AND	p.SourceSystemName = d.SourceSystemDesc
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ODS Extra Data
-- Date1, ExchangeDate, DateOfRenewal, ExpiryDate, RiskCountry, CertificateBondNumber
UPDATE
	p
SET
	CertificateBondNumber = o.CertificateBondNumber
	, Date1 = CONVERT (VARCHAR (10), o.Date1)
	, DateOfRenewal = CONVERT (VARCHAR (10), o.DateOfRenewal)
	, ExpiryDate = CONVERT (VARCHAR (10), o.ExpiryDate)
	, ExchangeDate = CONVERT (VARCHAR (10), o.ExchangeDate)
	, RiskCountry = o.RiskCountry
FROM
	#temp_MasterLog p, EDW..v_ODSExtraData o
WHERE
	p.PolicyID = o.PolicyID
	AND	p.PolicyLevelsCompoundId = o.PolicyLevelsCompoundId 
	AND	p.PolicyTransactionKey = o.PolicyTransactionKey
	AND	p.SourceSystemName = 'ODS'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from #temp_MasterLog where MasterPolicyNumber = '43-SUR-300058-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ExchangeRate 
-- Shred
UPDATE
	p
SET
	ExchangeRate = CASE WHEN p.OriginalPremium = 0 THEN 0
											ELSE	p.GrossPremiumUSD / p.OriginalPremium
								END
FROM
	#temp_MasterLog p
WHERE
	p.Currency <> 'USD'
	AND	p.SourceSystemName LIKE 'BHSI%'

-- ODS
UPDATE
	p
SET
	ExchangeRate = CONVERT (DECIMAL (13, 6), o.ExchangeRate)
FROM
	#temp_MasterLog p, EDW..v_ODSExtraData o
WHERE
	p.PolicyID = o.PolicyID
	AND	p.PolicyLevelsCompoundId = o.PolicyLevelsCompoundId 
	AND	p.PolicyTransactionKey = o.PolicyTransactionKey
	AND	p.SourceSystemName = 'ODS'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Apply Rate to convert different measure to USD
-- select * from #temp_MasterLog where masterpolicynumber = '43-XPR-000643-01'
UPDATE
	p
SET
	LimitUSD = p.Limit * p.ExchangeRate 
	, AttachmentPointUSD = p.AttachmentPoint * p.ExchangeRate 
FROM
	#temp_MasterLog p
WHERE
	p.Currency <> 'USD'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select Currency, exchangeDate, ExchangeRate, * from #temp_MasterLog where Currency <> 'USD'
-- select top 100 * from v_odsextradata where policynumber = '42-CNP-100465-02'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CompanyPaper update for Shred Sub/Quote
UPDATE
	p
SET
	CompanyPaper = CASE	WHEN	p.CompanyPaperNumber = 40	THEN '40/National Indemnity Company'
												WHEN	p.CompanyPaperNumber = 42	THEN '42/National Fire & Marine'
												WHEN	p.CompanyPaperNumber = 43	THEN '43/National Liability & Fire'
												WHEN	p.CompanyPaperNumber = 45	THEN '45/National Indemnity Company of Mid-America'
												WHEN	p.CompanyPaperNumber = 47	THEN '47/Berkshire Hathaway Specialty Insurance Company'
												ELSE	p.CompanyPaper
										END
FROM
	#temp_MasterLog p
WHERE
	p.SourceSystemName = 'BHSI Quote'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
select PolicyStatus, StatusCaption, TransactionType, CurrentStatus, * from #temp_MasterLog where CurrentStatus = 'Information'
select PolicyStatus, StatusCaption, TransactionType, CurrentStatus, SubmissionNumber, ProcessDate, * from #temp_MasterLog where MasterPolicyNumber like '%42-POC-302940-01%' order by 6
select PolicyStatus, StatusCaption, TransactionType, CurrentStatus, * from #temp_MasterLog where SubmissionNumber like '%16-06-03-037215%'
select CurrentStatus, OriginalPremium, * from #temp_MasterLog where TransactionType = 'Information'
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Current Status
-- New Approach for CurrentStatus, using a Mapping table to assign CurrentStatus
UPDATE
	p
SET
	CurrentStatus = ISNULL (c.CurrentStatus, p.CurrentStatus)
FROM
	#temp_MasterLog p, EDW..BHSI_CurrentStatus c
WHERE
--	LEFT (p.SourceSystemName, 4) = c.SourceSystemName
	CASE	WHEN	p.SourceSystemName LIKE 'BHSI%' THEN 'BHSI'
				ELSE p.SourceSystemName
	END
	= CASE WHEN c.SourceSystemName <> 'BHSI' THEN 'ODS'
					ELSE c.SourceSystemName
		END
	AND	p.PolicyStatus = c.PolicyStatus
	AND	p.StatusCaption = c.StatusCaption
	AND	p.TransactionType = c.TransactionType 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from bhsi_currentstatus where sourcesystemname = 'bhsi' and policystatus = 'cancelled' and transactiontype = 'ReviseEffectiveDate'
-- update bhsi_currentstatus set currentstatus = 'Bound' where currentstatusid = 42
-- select * from #temp_MasterLog where sourcesystemname like 'bhsi%' and policystatus = 'cancelled' and transactiontype = 'ReviseEffectiveDate'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ProcessDate Manual Update
-- Delete Certain Transactions  -- To be Reviewed Later
DELETE
	p
--select p.*
FROM
	#temp_MasterLog p, EDW.dbo.BHSI_ProcessDate_Update pd
WHERE
	p.RootDctId = pd.RootDctId
	AND	p.HistoryId = pd.HistoryId
	AND p.CurrentStatus = pd.CurrentStatus -- and t.MeasureName like 'w%' order by 3
	AND	p.GrossPremiumUSD = pd.PremiumInUSD
	AND	pd.ActionType = 'Delete Transaction From EDW'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--EXEC pr_Admin_Build_MasterLog
-- select distinct SourceSystemName, CurrentStatus from #temp_MasterLog order by 1, 2
--select SourceSystemName, PolicyStatus, StatusCaption, TransactionType, CurrentStatus, OriginalPremium, ProcessDate, * from #temp_MasterLog where PolicyStatus = 'WORKING' and StatusCaption = 'Quote' and TransactionType = 'Working'
--select * from #temp_MasterLog where transactiontype = 'rescind'
-- select distinct SourceSystemName, CurrentStatus  from #temp_MasterLog where isnull (ReasonCode, '') <> ''
-- select top 100 * from v_Audit_RiskFactor
--select SourceSystemName, PolicyId, PolicyStatus, StatusCaption, TransactionType, CurrentStatus, OriginalPremium, ProcessDate, ReasonCode, * from #temp_MasterLog where SubmissionNumber = '14-09-06-015098-01'
--select top 100 * from v_audit_riskfactor where policynumber = '14-09-06-015098-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ReasonCode
UPDATE
	p
SET
	ReasonCode		=	CASE	WHEN	p.CurrentStatus NOT LIKE '%LOST%' AND p.CurrentStatus NOT LIKE '%DECLINE%' THEN NULL
												ELSE	CASE	WHEN	p.SourceSystemName <> 'ODS' AND	CurrentStatus LIKE '%LOST%' THEN arf.LostReasonCode		
																		ELSE COALESCE (arf.DeclineReasonHolder, arf.ReasonCode)
															END
									END
FROM
	#temp_MasterLog p
		LEFT JOIN EDW.dbo.v_Audit_RiskFactor arf
			ON	p.PolicyId = arf.PolicyId
WHERE
	arf.RiskFactorType = 'PolicyRF'
-- 	and p.SubmissionNumber = '14-09-06-015098-01'

-- In a situation when ReasonCode is not populated in v_AuditRiskFactor , get ReasonCode (Description) from Static table where description is not populated
UPDATE
	p
SET
	ReasonCode = p.ReasonCode + ' - ' + rc.[Description]
FROM
	#temp_MasterLog p, EDW..BHSI_ReasonCode rc
WHERE
		p.ReasonCode = rc.Code
		AND	p.SourceSystemName LIKE '%BHSI%'

-- For certain Shred policies (eff between 2016-04-01 and 2016-07-14), ReasonCode comes from RS. This information is stored in a Static table in EDW
UPDATE
	p
SET
	ReasonCode = rc.ReasonCode
FROM
	#temp_MasterLog p, EDW..BHSI_ReasonCode_Frozen rc
WHERE
	p.SubmissionNumber = LEFT (rc.SubmissionNumber, LEN (rc.SubmissionNumber) - 3)
	AND	p.SourceSystemName LIKE 'BHSI%'
	AND	ISNULL (p.MasterPolicyNumber, '') = ''
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select distinct ReasonCode from #temp_Masterlog where isnull (masterpolicynumber, '') <> ''
-- select distinct SourceSystemName, CurrentStatus  from #temp_MasterLog where isnull (ReasonCode, '') <> ''
-- select ReasonCode, PolicyStatus, StatusCaption, TransactionType, CurrentStatus, OriginalPremium, * from #temp_MasterLog where SubmissionNumber like '17-01-02-051490%'
-- select ReasonCode, count (*) from #temp_MasterLog where currentstatus = 'lost' group by ReasonCode order by 1
-- select PolicyStatus, StatusCaption, TransactionType, CurrentStatus, OriginalPremium, ProcessDate, * from #temp_MasterLog where MasterPolicyNumber in ('')
-- select PolicyStatus, StatusCaption, TransactionType, CurrentStatus, OriginalPremium, * from #temp_MasterLog where SubmissionNumber LIKE '14-09-06-015098%' and isnull (MasterPolicyNumber, '') = ''
-- select PolicyStatus, StatusCaption, TransactionType, CurrentStatus, OriginalPremium, * from #temp_MasterLog where SubmissionNumber LIKE '14-08-06-015095%' and isnull (MasterPolicyNumber, '') = ''
-- select * from v_Layer where PolicyNumber like '42-EPT-303268-01%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Change Lost to either Lost-Indicated or Lost-Quoted
UPDATE
	p
SET
	CurrentStatus = CASE WHEN	p.ReasonCode LIKE 'LI%' THEN 'Lost-Indicated'
											WHEN	p.ReasonCode LIKE 'LQ%' THEN 'Lost-Quoted'
											ELSE	p.CurrentStatus
								END
FROM
	#temp_MasterLog p
WHERE
	CurrentStatus = 'Lost'

-- Current Status = Lost with NULL ReasonCode, Default to Lost-Quoted
UPDATE
	p
SET
	CurrentStatus = 'Lost-Quoted'
FROM
	#temp_MasterLog p
WHERE
	p.CurrentStatus = 'Lost'
	AND	p.ReasonCode IS NULL
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select Currency, OriginalPremium, TransactionType, StatusCaption, * from #temp_MasterLog where MasterPolicyNumber = '42-EPF-301575-02'
-- select ProcessDate, CurrentStatus, OriginalPremium, * from #temp_MasterLog where MasterPolicyNumber = '42-RLO-100208-03' order by 1, 2, 3
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Clean Up
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Delete Certain Types of Transactions
-- Issue Policy with 0 Premium
DELETE
	p
FROM
	#temp_MasterLog p
WHERE
	TransactionType = 'IssuePolicy'
	AND	OriginalPremium = 0

-- Void Policies
DELETE
	p
FROM
	#temp_MasterLog p
WHERE
	PolicyStatus = 'VOID'

-- Inforce - In Force - Information Transactions
DELETE
	p
FROM
	#temp_MasterLog p
WHERE
	p.PolicyStatus = 'Inforce'
--	AND	p.StatusCaption = 'In Force'
	AND	p.TransactionType = 'Information'

-- Entries with NULL or Empty InsuredName
DELETE
	p
--select count (*)
FROM
	#temp_MasterLog p
WHERE
	ISNULL (p.InsuredName, '') = ''

-- Entries with NULL or Empty BrokerName
DELETE
	p
--select count (*)
FROM
	#temp_MasterLog p
WHERE
	ISNULL (p.BrokerName, '') = ''
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select SourceSystemName, SourceSystemPolicyID, MasterPolicyNumber, SubmissionNumber, EffectiveDate, CurrentStatus, OriginalPremium, PolicyStatus, StatusCaption, TransactionType  from #temp_MasterLog where SourceSystemName = 'ODS'
-- select SourceSystemName, SourceSystemPolicyID, MasterPolicyNumber, SubmissionNumber, EffectiveDate, CurrentStatus, OriginalPremium, PolicyStatus, StatusCaption, TransactionType, *  from #temp_MasterLog where MasterPolicyNumber = '47-EPC-302624-01'
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Email Unmapped CurrentStatus
IF	OBJECT_ID ('tempDB..##temp_MissingStatus') IS NOT NULL	DROP	TABLE ##temp_MissingStatus
SELECT
	p.*
INTO
	##temp_MissingStatus
FROM
	(SELECT		DISTINCT SourceSystemName = CASE WHEN SourceSystemName LIKE 'BHSI%' THEN 'BHSI' WHEN SourceSystemName = 'ODS' THEN 'ODS' ELSE SourceSystemName END, SourceSystemPolicyID, PolicyStatus, StatusCaption, TransactionType FROM #temp_MasterLog) p
		LEFT OUTER JOIN (SELECT		DISTINCT SourceSystemName = CASE WHEN SourceSystemName = 'BHSI' THEN 'BHSI' ELSE 'ODS' END, PolicyStatus, StatusCaption, TransactionType FROM EDW..BHSI_CurrentStatus) c
			ON		p.SourceSystemName = c.SourceSystemName 
			AND	p.PolicyStatus = c.PolicyStatus
			AND	p.StatusCaption = c.StatusCaption
			AND	p.TransactionType = c.TransactionType
WHERE
	c.SourceSystemName IS NULL
	AND	c.PolicyStatus IS NULL
	AND	c.StatusCaption IS NULL
	AND	c.TransactionType IS NULL
-- select * from ##temp_MissingStatus

-- Send Email
IF	(SELECT COUNT (*) FROM ##temp_MissingStatus)> 0
BEGIN
	EXEC msdb.dbo.sp_send_dbmail  
		@profile_name = 'O365 SMTP Profile',  
		@recipients = 'Shaikh.Rahman@bhspecialty.com',  
--		@recipients = 'EDW_Support@bhspecialty.com',  
		@subject = 'CurrentStatus Mapping is Missing. Please Take Action!' ,  
		@query				= N'SELECT Source = LEFT (SourceSystemPolicyID, 10), PolicyStatus = LEFT (PolicyStatus, 20), StatusCaption = LEFT (StatusCaption, 40), TransactionType = LEFT (TransactionType, 40) from ##temp_MissingStatus ORDER BY 1, 2, 3, 4';
END
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
select distinct sourcesystemname from #temp_MasterLog
select CurrentStatus, sum (OriginalPremium) from #temp_MasterLog group by CurrentStatus order by 1
select MasterPolicyNumber, CurrentStatus, ActualProcessDate, ProcessDate, BindDate, EffectiveDate, OriginalPremium, PolicyNumber, * from #temp_MasterLog where MasterPolicyNumber like '%302744-01%' order by 3
select MasterPolicyNumber, CurrentStatus, ActualProcessDate, ProcessDate, BindDate, EffectiveDate, OriginalPremium, PolicyNumber, * from #temp_MasterLog where submissionnumber in ('15-05-02-010744', '15-06-03-012600', '15-08-02-016604','16-01-03-026792','16-01-03-026834','16-01-03-026847','16-01-03-026891', '17-03-02-057397', '16-12-03-049136')
select MasterPolicyNumber, SubmissionNumber, PolicyStatus, StatusCaption, TransactionType, CurrentStatus, OriginalPremium, * from #temp_MasterLog where PolicyStatus = 'bound' and StatusCaption = 'endorsement' and TransactionType = 'bond/cert.'
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select ProcessDate, CurrentStatus, OriginalPremium, * from #temp_MasterLog where MasterPolicyNumber like '%302338%' order by 1, 2
-- select SourceSystemName, MasterPolicyNumber, SUM (OriginalPremium) from #temp_MasterLog where isnull (MasterPolicyNumber, '') <> '' group by SourceSystemName, MasterPolicyNumber order by 1, 2
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Reassign SourceSystemName based on SourceSystemPolicyID
UPDATE
	p
SET
	SourceSystemName = CASE	WHEN	p.SourceSystemName LIKE'%BHSI%' THEN 'SRC_SUBM'
														WHEN	p.SourceSystemName = 'ODS' THEN ISNULL (p.SourceSystemPolicyID, p.SourceSystemName)
														ELSE	p.SourceSystemName
											END
FROM
		#temp_MasterLog p
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select distinct sourcesystemname, SourceSystemPolicyID from #temp_MasterLog
-- select top 100 * from #temp_MasterLog where masterpolicynumber like '%sur%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select count (*) from #temp_MasterLog
-- 96271
-- select count (*) from #temp_MasterLogFinal
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select policyglobalmasterid, * from #temp_MasterLog where MasterPolicyNumber in ('42-XSF-301129-01')
-- select Currency, OriginalPremium, CurrentStatus, TransactionType, StatusCaption, SourceSystemName, PolicyGlobalMasterId, * from #temp_MasterLog where MasterPolicyNumber = '43-LDA-150394-01' order by SubmissionNumber
-- select Currency, OriginalPremium, CurrentStatus, TransactionType, StatusCaption, SourceSystemName, PolicyGlobalMasterId, * from #temp_MasterLogFinal where MasterPolicyNumber = '43-LDA-150394-01' order by SubmissionNumber
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Final temporary table
IF	OBJECT_ID ('tempDB..#temp_MasterLogFinal') IS NOT NULL	DROP TABLE #temp_MasterLogFinal
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- RNO Ranking
-- Only Policy
SELECT
	p.*
	, RNO = CASE	WHEN	ISNULL (p.MasterPolicyNumber, '') = '' THEN 0
--							ELSE 	CASE	WHEN p.SourceSystemName = 'SRC_SUBM' THEN DENSE_RANK () OVER (PARTITION BY p.SubmissionNumber ORDER BY CONVERT (DATE, p.ActualProcessDate), p.ProcessDate, p.TransactionNumber)
--													ELSE	DENSE_RANK () OVER (PARTITION BY p.SourceSystemName, p.PolicyGlobalMasterId ORDER BY p.SourceSystemName, CONVERT (DATE, p.ActualProcessDate), p.ProcessDate, p.TransactionNumber)
--										END
							ELSE 	CASE	WHEN p.SourceSystemName = 'SRC_SUBM' THEN DENSE_RANK () OVER (PARTITION BY p.SubmissionNumber ORDER BY p.TransactionDateTime, p.ProcessDate, p.TransactionNumber)
													ELSE	DENSE_RANK () OVER (PARTITION BY p.SourceSystemName, p.PolicyGlobalMasterId ORDER BY p.SourceSystemName, p.TransactionDateTime, p.ProcessDate, p.TransactionNumber)
										END
					END	
INTO
	#temp_MasterLogFinal
FROM
	#temp_MasterLog p
WHERE
	p.OldPolicyType = 'P'
--and p.MasterPolicyNumber = '42-XSF-301129-01'

-- Only Submission
INSERT	INTO #temp_MasterLogFinal
SELECT
	p.*
	, RNO = 0
FROM
	#temp_MasterLog p
WHERE
	p.OldPolicyType <> 'P'
---------------------------------------------------------------------------------------------------------------------------------------------------
-- select CurrentStatus, OriginalPremium, PolicyGlobalMasterId, * from #temp_MasterLogFinal where MasterPolicyNumber = '42-Not Applicable-NT/APP-01' order by 8
---------------------------------------------------------------------------------------------------------------------------------------------------
-- Also add this suffix to SubmissionNumber Field for DOM_SUBM and SRC_SUBM for Bound Policies
UPDATE
	p
SET
	SubmissionNumber = CASE	WHEN	p.SourceSystemName = 'SRC_SUBM' THEN p.SubmissionNumber + '-' + RIGHT ('00' + CONVERT (VARCHAR (3), p.Rno), 2)
														ELSE	p.PolicyGlobalMasterId + '-' + RIGHT ('00' + CONVERT (VARCHAR (3), p.Rno), 2)
											END
FROM
	#temp_MasterLogFinal p
WHERE
	ISNULL (p.MasterPolicyNumber, '') <> ''
	AND	p.SourceSystemName IN ('SRC_SUBM', 'DOM_SUBM')
--	AND	p.MasterPolicyNumber NOT IN  ('42-Not Applicable-NT/APP-01')
--	AND	p.MasterPolicyNumber NOT LIKE '%NT/APP%'

-- Also add this suffix to SubmissionNumber Field for SRC_SUBM for Pre Bound
UPDATE
	p
SET
	SubmissionNumber = p.SubmissionNUmber + '-01'
FROM
	#temp_MasterLogFinal p
WHERE
	ISNULL (p.MasterPolicyNumber, '') = ''
	AND	p.SourceSystemName IN ('SRC_SUBM')
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
select count (*) from #temp_MasterLogFinal where isnull (insuredstate, '') = ''
select CurrentStatus, OriginalPremium, Rno, * from #temp_MasterLogFinal where MasterPolicyNumber = '42-CNP-100460-02' order by SubmissionNumber
select CurrentStatus, OriginalPremium, Rno, * from #temp_MasterLogFinal where SubmissionNumber like '%42-CNP-100460-01%' order by SubmissionNumber
select MasterPolicyNumber, count (*) from #temp_MasterLogFinal where isnull (MasterPolicyNumber, '') <> '' and SourceSystemName = 'DOM_SUBM' group by MasterPolicyNumber having count (*) > 1 order by 1, 2
select distinct MasterPolicyNumber, SubmissionNumber, PolicyGlobalMasterId from #temp_MasterLogFinal where isnull (MasterPolicyNumber, '') <> '' and SourceSystemName = 'DOM_SUBM' order by 1, 2
select Rno, MasterPolicyNumber, SubmissionNumber, PolicyGlobalMasterId, CurrentStatus, OriginalPremium, PolicyStatus, StatusCaption, TransactionType, * from #temp_MasterLogFinal where MasterPolicyNumber like '%42-CEQ-NT/APP-01%' order by 3, 1
select distinct Rno from #temp_MasterLogFinal p where p.SourceSystemName = 'DOM_SUBM' AND (p.MasterPolicyNumber NOT LIKE '%SUR%' OR p.MasterPolicyNumber NOT LIKE '%Not Applicable%') and isnull (MasterPolicyNumber, '') <> ''

select MasterPolicyNumber, SubmissionNumber, InsuredName, PolicyStatus, StatusCaption, TransactionType, CurrentStatus, OriginalPremium, RNo, * from #temp_MasterLogFinal where MasterPolicyNumber = '42-Not Applicable-NT/APP-01' order by 1, 2
select * from #temp_MasterLog where MasterPolicyNumber = '42-Not Applicable-NT/APP-01' order by 5
select * from #temp_MasterLogFinal where rno > 99
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select distinct brancoffice from #temp_MasterLogFinal where sourcesystemname like 'src%' order by 1
-- select *  from #temp_MasterLogFinal order by 1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Temporarily Remove Non-North America information
-- Worker's Comp
DELETE
	p
--select *
FROM
	#temp_MasterLogFinal p
WHERE
	ProductLineSubType = 'WorkersComp'
	AND	SourceSystemName = 'SRC_SUBM'

-- BranchOffice Australia and New Zealand
DELETE
	p
--select BrancOffice, *
FROM
	#temp_MasterLogFinal p
WHERE
	(p.BrancOffice LIKE '%Australia%' OR p.BrancOffice LIKE '%New Zealand%' OR p.BrancOffice LIKE '%Toronto%' OR p.BrancOffice LIKE '%Hong Kong%' OR p.BrancOffice LIKE '%Singapore%')
	AND	p.SourceSystemName = 'SRC_SUBM'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from #temp_MasterLog where MasterPolicyNumber = '42-PRP-000071-04'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Create the physical table with Reversal entries.
IF	OBJECT_ID ('EDW.dbo.MasterLog_From_EDW_PC') IS NOT NULL	DROP TABLE EDW.[dbo].[MasterLog_From_EDW_PC]
SELECT
	LoadDate, AsofDate, Rno, Sort_Order, SourceSystemName, SubmissionNumber, DuckCreekSubmissionNumber, MasterPolicyNumber, NewRenewal, InsuredName, AdvisenId, ReasonCodeMeaning, Underwriter
	, ProductLine, ProductLineSubType, Section, ProfitCode, ProjectType, ISOCode, CurrentStatus, EffectiveDate, ExpiryDate, ProcessDate, BindDate, Renewable, DateOfRenewal, PolicyType, DirectAssumed
	, CompanyPaper, CompanyPaperNumber, Coverage, PolicyNumber, Suffix, TransactionNumber, AdmittedNonAdmitted, ClassName, ClassCode, BrokerName, BrokerType, AlternativeAddress1, BrokerContactPerson
	, BrokerCountry, BrokerState, BrokerCity, BrokerContactPersonStreetAddress, BrokerContactPersonZipCode, BrokerCode, BrokerContactPersonEmail, BrokerContactPersonNumber, BrokerContactPersonMobile
	, RetailBroker, RetailBrokerCountry, RetailBrokerState, RetailBrokerCity, BrancOffice, Currency, ExchangeRate = CONVERT (NUMERIC (18, 4), ExchangeRate), ExchangeDate, LayerofLimitInLocalCurrency, LayerofLimitInUSD, PercentageofLayer, Limit
	, LimitUSD, AttachmentPoint, AttachmentPointUSD, SelfInsuredRetentionInLocalCurrency, SelfInsuredRetentionInUSD, OriginalPremium, GrossPremiumUSD, PolicyCommPercentage, PolicyCommInLocalCurrency
	, PolicyCommInUSD, PremiumNetofCommInLocalCurrency, PremiumNetofCommInUSD, ReasonCode, CabCompanies, TotalInsuredValue, TotalInsuredValueInUSD, AlternativeZipCode, AlternativeState
	, RiskProfile, ProjectName, GeneralContractor, ProjectOwnerName, ProjectStreetAddress, ProjectCountry, ProjectState, ProjectCity, BidSituation, ReinsuredCompany, DBNumber, NAICCode, NAICTitle
	, OfrcReport, DBAName, InsuredCountry, InsuredState, InsuredCity, InsuredMailingAddress1, InsuredZipcode, InsuredContactPerson, InsuredContactPersonEmail, InsuredContactPersonPhone
	, InsuredContactPersonMobile, InsuredSubmissionDate, insuredQuoteDueDate, ByBerksiFromBroker, ByIndiaFromBerksi, Date1, Status1, Remark1, Date2, Status2, Remark2, Date3, Status3, Remark3
	, Date4, Status4, Remark4, Date5, Status5, Remark5, DateForAmendment, AttachmentType, IssuingOffice, IssuingUnderwriter, deductibleinLocalCurrency, deductibleinUSD, ActualProcessDate, latitude
	, longitude, Affiliation, CertificateBondNumber, RiskCountry, Occupancy, NumberOfLocations, SourceSystemInsuredId, GUPAdvisenId, AdvisenUltimateParentCompanyName, AdvisenTicker
	, AdvisenSicPrimaryNumeric, AdvisenSicPrimaryNumericDesc, AdvisenRevenue, AdvisenDescOfOperations
INTO 
	EDW.dbo.MasterLog_From_EDW_PC
FROM 
	#temp_MasterLogFinal 
WHERE
	DeletedFlag = 0
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select CurrentStatus, OriginalPremium, PolicyCommInLocalCurrency, PolicyCommPercentage, *  from #temp_MasterLogFinal  where MasterPolicyNumber = '40-PRI-302594-01' order by submissionnumber
-- select CurrentStatus, OriginalPremium, PolicyCommInLocalCurrency, PolicyCommPercentage, * from #temp_MasterLogFinal  where MasterPolicyNumber = '42-EMC-302851-01' order by submissionnumber
-- select distinct CurrentStatus from #temp_MasterLogFinal  where isnull (MasterPolicyNumber, '') <> '' and SourceSystemName = 'src_subm'
-- select ProcessDate, CurrentStatus, OriginalPremium, * from #temp_MasterLogFinal where MasterPolicyNumber = '40-PRI-302594-01' order by 1, 2, 3
-- select ProcessDate, CurrentStatus, OriginalPremium, PolicyCommInLocalCurrency, PolicyTransactionId, * from #temp_MasterLogFinal where MasterPolicyNumber like '%40-PRI-302594-01%' order by 1, 2, 3
-- select * from bhsi_transaction where policytransactionid = 64768603 and measurename like 'w%'
-- select policytransactionid, measurename, transactiontype, count (*) from bhsi_transaction where transactiontype not like 'adj%' group by policytransactionid, measurename, transactiontype having count (*) > 1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Fix Source Policy Commission Amount for a handfull of policies where commission pct is changed
UPDATE
	p1
SET
--select
	PolicyCommInLocalCurrency = p1.RunningTransactionAmount_OC - p2.RunningTransactionAmount_OC 
	, PolicyCommInUSD = p1.RunningTransactionAmount - p2.RunningTransactionAmount 
FROM
	#temp_MasterLogFinal p1, #temp_MasterLogFinal p2
WHERE
	p1.MasterPolicyNumber = p2.MasterPolicyNumber 
	AND	p1.SourceSystemName = 'SRC_SUBM'
	AND	p1.RNO =p2.RNO + 1
--	and p1.MasterPolicyNumber = '40-PRI-302594-01'
	AND	p1.MasterPolicyNumber IN (SELECT a.PolicyNumber FROM (SELECT	DISTINCT PolicyNumber, CommissionPercent FROM EDW.dbo.v_CommissionPercent cp WHERE cp.SourceSystemDesc LIKE 'BHSI%' ) a GROUP BY a.PolicyNumber HAVING COUNT (*) > 1) 
	AND	p1.CurrentStatus IN ('Bound', 'Reversal', 'ReviseBind')
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 ProcessDate, CurrentStatus, OriginalPremium, historyid, * from #temp_MasterLogFinal where MasterPolicyNumber = '42-XPR-000211-03' order by 1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remove Reversal Entries
DELETE
	p
--select top 100 processdate, originalpremium, historyid, *
FROM
	#temp_MasterLogFinal p
WHERE
	p.CurrentStatus = 'Reversal'
--and MasterPolicyNumber = '42-XPR-000211-03'

-- Update ReviseBind Entries
UPDATE
	p
SET
--select top 100 p.processdate, originalpremium, p.historyid, p.TransactionType,
	OriginalPremium = t.Src_TransactionAmount_OC
	, GrossPremiumUSD = t.Src_TransactionAmount
--, t.*
FROM
	#temp_MasterLogFinal p, EDW..BHSI_Transaction t
WHERE
	p.PolicyTransactionId = t.PolicyTransactionId
	AND	p.CurrentStatus = 'ReviseBind'
	AND	t.MeasureName IN ('GrossPremium', 'WrittenPremium', 'GrossPremiumInUSD', 'WrittenPremiumInUSD')
	AND	t.TransactionType = 'ReviseBind'
	AND	p.SourceSystemName = 'SRC_SUBM'
-- and p.MasterPolicyNumber = '42-XPR-000211-03' order by 1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 ProcessDate, CurrentStatus, OriginalPremium, historyid, * from #temp_MasterLogFinal where MasterPolicyNumber = '42-XPR-000211-03' order by 4
-- select ProcessDate, * from BHSI_Transaction where PolicyNumber = '42-XPR-000211-03' and transactiontype = 'revisebind' and measurename like '%prem%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
select CurrentStatus, OriginalPremium, PolicyCommPercentage, PolicyCommInLocalCurrency, * from #temp_MasterLog where MasterPolicyNumber = '42-PRP-000345-03'
select * from #temp_PropertyLayer where PolicyNumber = '42-PRP-000345-03'
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- For Shred Property Layered Policies, Get Comm Pct from NonAdditiveMeausre table LayerCommission field
IF	OBJECT_ID ('tempDB..#temp_PropertyLayer') IS NOT NULL	DROP TABLE #temp_PropertyLayer
SELECT
	commPct.PolicyId, commPct.PolicyNumber, commPct.MasterPolicyNumber, commPct.SourceSystemDesc
	, LayerPremium_OC = SUM (LayerPremium_OC), CommissionAmount = SUM (CommissionAmount)
	, CommPct = CASE	WHEN	 SUM (LayerPremium_OC) = 0 THEN 0
									ELSE		SUM (CommissionAmount) / SUM (LayerPremium_OC)
						END
INTO
	#temp_PropertyLayer
FROM
	(
	SELECT
		l.PolicyId, a.PolicyNumber, a.MasterPolicyNumber, a.SourceSystemDesc, l.LayerPremium_OC, n.LayerCommission, CommissionAmount = l.LayerPremium_OC *n.LayerCommission
	FROM
		EDW.dbo.v_Layer l, EDW.dbo.v_NonAdditiveMeasure n, (SELECT PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemDesc FROM EDW..v_Layer WHERE 	PolicyNumber IN (SELECT DISTINCT MasterPolicyNumber FROM #temp_MasterLog WHERE ProductLine = 'Property') AND	SourceSystemDesc LIKE 'BHSI%' GROUP BY PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemDesc HAVING COUNT (*) > 1) a
	WHERE
		l.PolicyId = n.PolicyId
		AND	l.LayerId = n.LayerId
		AND	l.PolicyId = a.PolicyId
	--and l.policyid = 110099514
	) commPct
GROUP BY 
	commPct.PolicyId, commPct.PolicyNumber, commPct.MasterPolicyNumber, commPct.SourceSystemDesc

UPDATE
	p
SET
	PolicyCommPercentage = l.CommPct * 100 
	, PolicyCommInLocalCurrency = p.OriginalPremium * l.CommPct
	, PremiumNetofCommInLocalCurrency = p.OriginalPremium - p.OriginalPremium * l.CommPct
	, PolicyCommInUSD = p.GrossPremiumUSD * l.CommPct
	, PremiumNetofCommInUSD = p.GrossPremiumUSD - p.GrossPremiumUSD * l.CommPct
FROM
	#temp_MasterLogFinal p, #temp_PropertyLayer l
WHERE
	p.PolicyId = l.PolicyId
--	and p.MasterPolicyNumber = '42-PRP-000345-03'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Net Premium = Original Prem - Comm
UPDATE
	p
SET
	PremiumNetofCommInLocalCurrency = p.OriginalPremium - p.PolicyCommInLocalCurrency 
	, PremiumNetofCommInUSD 	= p.GrossPremiumUSD - p.PolicyCommInUSD 
FROM
	#temp_MasterLogFinal p
WHERE
	p.SourceSystemName = 'SRC_SUBM'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Create the Physical Table
IF	OBJECT_ID ('EDW.dbo.MasterLog_From_EDW') IS NOT NULL	DROP TABLE EDW.[dbo].[MasterLog_From_EDW]
SELECT
	LoadDate, AsofDate, Rno, Sort_Order, SourceSystemName, SubmissionNumber, DuckCreekSubmissionNumber, MasterPolicyNumber, NewRenewal, InsuredName, AdvisenId, ReasonCodeMeaning, Underwriter
	, ProductLine, ProductLineSubType, Section, ProfitCode, ProjectType, ISOCode, CurrentStatus, EffectiveDate, ExpiryDate, ProcessDate, BindDate, Renewable, DateOfRenewal, PolicyType, DirectAssumed
	, CompanyPaper, CompanyPaperNumber, Coverage, PolicyNumber, Suffix, TransactionNumber, AdmittedNonAdmitted, ClassName, ClassCode, BrokerName, BrokerType, AlternativeAddress1, BrokerContactPerson
	, BrokerCountry, BrokerState, BrokerCity, BrokerContactPersonStreetAddress, BrokerContactPersonZipCode, BrokerCode, BrokerContactPersonEmail, BrokerContactPersonNumber, BrokerContactPersonMobile
	, RetailBroker, RetailBrokerCountry, RetailBrokerState, RetailBrokerCity, BrancOffice, Currency, ExchangeRate = CONVERT (NUMERIC (18, 4), ExchangeRate), ExchangeDate, LayerofLimitInLocalCurrency, LayerofLimitInUSD, PercentageofLayer, Limit
	, LimitUSD, AttachmentPoint, AttachmentPointUSD, SelfInsuredRetentionInLocalCurrency, SelfInsuredRetentionInUSD, OriginalPremium, GrossPremiumUSD, PolicyCommPercentage, PolicyCommInLocalCurrency
	, PolicyCommInUSD, PremiumNetofCommInLocalCurrency, PremiumNetofCommInUSD, ReasonCode, CabCompanies, TotalInsuredValue, TotalInsuredValueInUSD, AlternativeZipCode, AlternativeState
	, RiskProfile, ProjectName, GeneralContractor, ProjectOwnerName, ProjectStreetAddress, ProjectCountry, ProjectState, ProjectCity, BidSituation, ReinsuredCompany, DBNumber, NAICCode, NAICTitle
	, OfrcReport, DBAName, InsuredCountry, InsuredState, InsuredCity, InsuredMailingAddress1, InsuredZipcode, InsuredContactPerson, InsuredContactPersonEmail, InsuredContactPersonPhone
	, InsuredContactPersonMobile, InsuredSubmissionDate, insuredQuoteDueDate, ByBerksiFromBroker, ByIndiaFromBerksi, Date1, Status1, Remark1, Date2, Status2, Remark2, Date3, Status3, Remark3
	, Date4, Status4, Remark4, Date5, Status5, Remark5, DateForAmendment, AttachmentType, IssuingOffice, IssuingUnderwriter, deductibleinLocalCurrency, deductibleinUSD, ActualProcessDate, latitude
	, longitude, Affiliation, CertificateBondNumber, RiskCountry, Occupancy, NumberOfLocations, SourceSystemInsuredId, GUPAdvisenId, AdvisenUltimateParentCompanyName, AdvisenTicker
	, AdvisenSicPrimaryNumeric, AdvisenSicPrimaryNumericDesc, AdvisenRevenue, AdvisenDescOfOperations 
INTO 
	EDW.dbo.MasterLog_From_EDW
FROM 
	#temp_MasterLogFinal 
WHERE
	DeletedFlag = 0
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
-- To Mimic Blended_ODS_Daily
IF	OBJECT_ID ('EDW.dbo.MasterLog_Aggregated_From_EDW') IS NOT NULL	DROP TABLE EDW.[dbo].MasterLog_Aggregated_From_EDW
SELECT
	CRM_InsuredNumber = '', ModifiedDuckCreekSubmissionNumber = DuckCreekSubmissionNumber, ReservationsSubmissionNumber = '', ReservationsDuckCreekSubmissionNumber = '', LoadDate
	, a.SourceSystemName, BrokerName_temp = BrokerName, BrokerStatus_temp = '', BrokerType_Temp = BrokerType, Createddate = LoadDate, a.Rno, Sort_Order
	, SubmissionNumber = a.SubmissionNumber + '-01'
	, DuckCreekSubmissionNumber, a.MasterPolicyNumber, NewRenewal, InsuredName, AdvisenId	, SubmissionTypeIdentifier = PolicyType, Underwriter
	, ProductLine, ProductLineSubType, Section, ProfitCode, ProjectType, ISOCode, CurrentStatus, EffectiveDate, ExpiryDate, ProcessDate, BindDate, Renewable, DateOfRenewal, PolicyType, DirectAssumed
	, CompanyPaper, CompanyPaperNumber, Coverage, PolicyNumber, Suffix, TransactionNumber, AdmittedNonAdmitted, ClassName, ClassCode, BrokerName, BrokerType
	, SubTypeOfBroker = '', BrokerContactPerson
	, BrokerCountry, BrokerState, BrokerCity, BrokerContactPersonStreetAddress, BrokerContactPersonZipCode, BrokerCode, BrokerContactPersonEmail, BrokerContactPersonNumber, BrokerContactPersonMobile
	, RetailBroker, RetailBrokerCountry, RetailBrokerState, RetailBrokerCity, BrancOffice, Currency, ExchangeRate = CONVERT (NUMERIC (18, 4), a.ExchangeRate), a.ExchangeDate, LayerofLimitInLocalCurrency, LayerofLimitInUSD, PercentageofLayer, Limit
	, LimitUSD, AttachmentPoint, AttachmentPointUSD, SelfInsuredRetentionInLocalCurrency, SelfInsuredRetentionInUSD
	, OriginalPremium = SUM (b.OriginalPremium), GrossPremiumUSD = SUM (b.GrossPremiumUSD)
	, PolicyCommPercentage, PolicyCommInLocalCurrency
	, PolicyCommInUSD, PremiumNetofCommInLocalCurrency, PremiumNetofCommInUSD, ReasonCode, CabCompanies
	, TotalInsuredValue = MAX (TotalInsuredValue), TotalInsuredValueInUSD = MAX (TotalInsuredValueInUSD)
	, OccupancyCode = '', NumberofLocationsGreaterThan3 = ''
	, RiskProfile, ProjectName, GeneralContractor, ProjectOwnerName, ProjectStreetAddress, ProjectCountry, ProjectState, ProjectCity, BidSituation, ReinsuredCompany, DBNumber, NAICCode, NAICTitle, OfrcReport
	, DBAName, InsuredCountry, InsuredState, InsuredCity, InsuredMailingAddress1, InsuredZipcode, InsuredContactPerson, InsuredContactPersonEmail, InsuredContactPersonPhone, InsuredContactPersonMobile
	, InsuredSubmissionDate, insuredQuoteDueDate, ByBerksiFromBroker, ByIndiaFromBerksi, Date1, Status1, Remark1, Date2, Status2, Remark2, Date3, Status3, Remark3, Date4, Status4, Remark4, Date5, Status5
	, Remark5, DateForAmendment, AttachmentType
INTO
	EDW.dbo.MasterLog_Aggregated_From_EDW
FROM
	#temp_MasterLogFinal a
		JOIN (	
					SELECT
						m.SubmissionNumber, m.MasterPolicyNumber, m.SourceSystemName, m.RNO,  ExchangeDate = CONVERT (VARCHAR (10), MAX (ExchangeDate), 120), m.OriginalPremium, m.GrossPremiumUSD 
					FROM
						(
							SELECT SubmissionNumber, MasterPolicyNumber, SourceSystemName, OriginalPremium = SUM (OriginalPremium), GrossPremiumUSD = SUM (GrossPremiumUSD), RNO = MAX (RNO)--, ExchangeDate = CONVERT (VARCHAR (10), MAX (ExchangeDate), 120)
							FROM #temp_MasterLogFinal  
							WHERE
--								submissionnumber like '%002923%' and
								DeletedFlag = 0
							GROUP BY SubmissionNumber, MasterPolicyNumber, SourceSystemName
						) m
						JOIN #temp_MasterLogFinal n
							ON		m.SubmissionNumber = n.SubmissionNumber 
							AND	m.MasterPolicyNumber = n.MasterPolicyNumber 
							AND	m.SourceSystemName = n.SourceSystemName 
							AND	ISNULL (m.RNO, -1) = ISNULL (n.RNO, -1)
							AND	n.DeletedFlag = 0
						GROUP BY m.SubmissionNumber, m.MasterPolicyNumber, m.SourceSystemName, m.RNO, m.OriginalPremium, m.GrossPremiumUSD 
				 ) b
			ON		CONVERT (VARCHAR (10), a.ExchangeDate, 120) = b.ExchangeDate
			AND	ISNULL (a.RNO, -1) = ISNULL (b.RNO, -1)
			AND	a.SourceSystemName = b.SourceSystemName
			AND	a.SubmissionNumber = b.SubmissionNumber
WHERE
	DeletedFlag = 0
GROUP BY
	DuckCreekSubmissionNumber, LoadDate
	, a.SourceSystemName, BrokerName, BrokerType, LoadDate, a.Rno, Sort_Order
	, a.SubmissionNumber
	, DuckCreekSubmissionNumber, a.MasterPolicyNumber, NewRenewal, InsuredName, AdvisenId, PolicyType, Underwriter
	, ProductLine, ProductLineSubType, Section, ProfitCode, ProjectType, ISOCode, CurrentStatus, EffectiveDate, ExpiryDate, ProcessDate, BindDate, Renewable, DateOfRenewal, PolicyType, DirectAssumed
	, CompanyPaper, CompanyPaperNumber, Coverage, PolicyNumber, Suffix, TransactionNumber, AdmittedNonAdmitted, ClassName, ClassCode, BrokerName, BrokerType
	, BrokerContactPerson
	, BrokerCountry, BrokerState, BrokerCity, BrokerContactPersonStreetAddress, BrokerContactPersonZipCode, BrokerCode, BrokerContactPersonEmail, BrokerContactPersonNumber, BrokerContactPersonMobile
	, RetailBroker, RetailBrokerCountry, RetailBrokerState, RetailBrokerCity, BrancOffice, Currency, a.ExchangeRate, a.ExchangeDate, LayerofLimitInLocalCurrency, LayerofLimitInUSD, PercentageofLayer, Limit
	, LimitUSD, AttachmentPoint, AttachmentPointUSD, SelfInsuredRetentionInLocalCurrency, SelfInsuredRetentionInUSD
--	, OriginalPremium = SUM (OriginalPremium), GrossPremiumUSD = SUM (GrossPremiumUSD)
	, PolicyCommPercentage, PolicyCommInLocalCurrency
	, PolicyCommInUSD, PremiumNetofCommInLocalCurrency, PremiumNetofCommInUSD, ReasonCode, CabCompanies
--	, TotalInsuredValue = SUM (TotalInsuredValue), TotalInsuredValueInUSD = SUM (TotalInsuredValueInUSD)
	, RiskProfile, ProjectName, GeneralContractor, ProjectOwnerName, ProjectStreetAddress, ProjectCountry, ProjectState, ProjectCity, BidSituation, ReinsuredCompany, DBNumber, NAICCode, NAICTitle, OfrcReport
	, DBAName, InsuredCountry, InsuredState, InsuredCity, InsuredMailingAddress1, InsuredZipcode, InsuredContactPerson, InsuredContactPersonEmail, InsuredContactPersonPhone, InsuredContactPersonMobile
	, InsuredSubmissionDate, insuredQuoteDueDate, ByBerksiFromBroker, ByIndiaFromBerksi, Date1, Status1, Remark1, Date2, Status2, Remark2, Date3, Status3, Remark3, Date4, Status4, Remark4, Date5, Status5
	, Remark5, DateForAmendment, AttachmentType
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- pr_Admin_Build_MasterLog
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
*/
