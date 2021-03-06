-- drop PROCEDURE [dbo].[pr_Admin_Build_BHSITransaction]
ALTER PROCEDURE [dbo].[pr_Admin_Build_BHSITransaction]
AS
-----------------------------------------------------------------------------------------------------------------------------------------------------
IF EXISTS(SELECT 1 FROM tempdb..sysobjects AS t WHERE t.id = OBJECT_ID('tempdb..#Temp_BHSI_Transaction'))	
	DROP TABLE #Temp_BHSI_Transaction
-----------------------------------------------------------------------------------------------------------------------------------------------------
CREATE	TABLE #Temp_BHSI_Transaction (
	PolicyId								INT
	, AsOfPolicyId						INT
	, PolicyNumber							VARCHAR (100)
	, MasterPolicyNumber					VARCHAR (100)
	, SourceSystemId						INT
	, SourceSystemDesc						VARCHAR (100)
	, PolicyType							VARCHAR (2)
	, TransactionDate						DATETIME2 NULL
	, TransactionEffectiveDate				DATETIME NULL
	, TransactionIssueDate					DATETIME NULL
	, AccountingBookDate					DATETIME NULL
	, TransactionType						VARCHAR (100) NULL
	, MeasureName							VARCHAR (100) NULL
	, CurrencyCode							VARCHAR (10) NULL
	, TransactionAmount_OC					NUMERIC (38, 8) NULL
	, TransactionAmount						NUMERIC (38, 8) NULL
	, PolicyTransactionId					INT NULL
	, PolicyTransactionKey					VARCHAR (150) NULL
	, DataVarInd							VARCHAR (2) NULL
	, PolicyKey								VARCHAR (100) NULL
	, PolicyLevelsCompoundID				INT NULL
	, XrefPolicyLevelStartDate				DATETIME2 NULL
	, XrefPolicyLevelEndDate				DATETIME2 NULL
	, XrefDataVarInd						VARCHAR (2) NULL
	, DeprecatedDate						DATETIME2
	, RunningTransactionAmount_OC			NUMERIC (38, 8) NULL
	, RunningTransactionAmount				NUMERIC (38, 8) NULL
	, Seq									SMALLINT NULL
	, Region								VARCHAR (100) NULL  DEFAULT 'North America'
	, ProcessDate							DATETIME NULL
	, OldTransactionDate					DATETIME2 NULL
	, TransactionDateDerived				DATETIME2 NULL
)
-----------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------
--Policy
INSERT	INTO	#Temp_BHSI_Transaction
	(
	MasterPolicyNumber
	, PolicyNumber
	, SourceSystemId
	, SourceSystemDesc
	, PolicyType
	, TransactionDate
	, TransactionEffectiveDate
	, TransactionIssueDate
	, AccountingBookDate
	, TransactionType
	, MeasureName
	, CurrencyCode
	, TransactionAmount_OC
	, TransactionAmount
	, PolicyTransactionId
	, PolicyTransactionKey
	, DataVarInd
	, PolicyKey
	, PolicyID
	, PolicyLevelsCompoundID
	, XrefPolicyLevelStartDate
	, XrefPolicyLevelEndDate
	, XrefDataVarInd
	, DeprecatedDate
	, RunningTransactionAmount_OC
	, RunningTransactionAmount
	, Seq
	, TransactionDateDerived
	)

SELECT 
		MasterPolicyNumber
		, PolicyNumber 
		, SourceSystemId 
		, SourceSystemDesc 
		, PolicyType 
		, TransactionDate 
		, TransactionEffectiveDate 
		, TransactionIssueDate 	
		, AccountingBookDate 
		, TransactionType 
		, MeasureName = 'WrittenPremium'
		, CurrencyCode 
		, TransactionAmount_OC 
		, TransactionAmount 
		, PolicyTransactionId 
		, PolicyTransactionKey 
		, DataVarInd 
		, PolicyKey 
		, PolicyID 
		, PolicyLevelsCompoundID 
		, XrefPolicyLevelStartDate 
		, XrefPolicyLevelEndDate 
		, XrefDataVarInd 
		, DeprecatedDate 
		, RunningTransactionAmount_OC = CASE WHEN SourceSystemDesc LIKE 'BHSI%' THEN SUM([TransactionAmount_OC]) OVER(partition by policykey ORDER BY TransactionDate ROWS UNBOUNDED PRECEDING) ELSE NULL END -- and tType.TransactionTypeDesc IN ('Renew', 'New', 'Rewrite', 'ReviseEffectiveDate', 'ReviseBind')
		, RunningTransactionAmount    = CASE WHEN SourceSystemDesc LIKE 'BHSI%' THEN SUM([TransactionAmount]) OVER(partition by policykey ORDER BY TransactionDate ROWS UNBOUNDED PRECEDING) ELSE NULL END	   -- and tType.TransactionTypeDesc IN ('Renew', 'New', 'Rewrite', 'ReviseEffectiveDate', 'ReviseBind')
		, Seq = RANK() OVER(partition by policykey ORDER BY transactionDate, PolicyTransactionKey)
		, TransactionDateDerived
from (
	SELECT 
		MasterPolicyNumber= p.MasterPolicyNumber
		, PolicyNumber = p.PolicyNumber
		, SourceSystemId = p.SourceSystemId 
		, SourceSystemDesc = ss.SourceSystemDesc
		, PolicyType = p.PolicyType
		, TransactionDate = t1.TransactionDate														-- CONVERT (DATETIME, CONVERT (VARCHAR (10), t1.TransactionDate, 120)
		, TransactionEffectiveDate = t1.TransactionEffectiveDate
		, TransactionIssueDate = t1.TransactionIssueDate
	--	, AccountingBookDate = t1.AccountingBookDate
		, AccountingBookDate = CASE	WHEN ss.SourceSystemDesc LIKE 'BHSI%'	THEN
																						CASE	WHEN	t1.TransactionEffectiveDate > CONVERT (DATE, t1.TransactionDate)  AND t1.TransactionEffectiveDate <= cal.CutOffDate THEN t1.TransactionEffectiveDate
																									WHEN	t1.TransactionEffectiveDate > CONVERT (DATE, t1.TransactionDate) AND t1.TransactionEffectiveDate > cal.CutOffDate THEN t1.TransactionEffectiveDate
																									WHEN	t1.TransactionEffectiveDate < CONVERT (DATE, t1.TransactionDate) AND CONVERT (DATE, t1.TransactionDate) <= cal.CutOffDate THEN CONVERT (DATE, t1.TransactionDate)
																									WHEN	t1.TransactionEffectiveDate < CONVERT (DATE, t1.TransactionDate) AND CONVERT (DATE, t1.TransactionDate) > cal.CutOffDate AND CONVERT (VARCHAR (10), t1.TransactionDate, 120) <= CONVERT (VARCHAR (10), cal.EndDate - 1, 120) THEN  cal.EndDate 
																									WHEN	t1.TransactionEffectiveDate < CONVERT (DATE, t1.TransactionDate) AND CONVERT (DATE, t1.TransactionDate) > cal.CutOffDate AND CONVERT (VARCHAR (10), t1.TransactionDate, 120) > CONVERT (VARCHAR (10), cal.EndDate - 1, 120)THEN CONVERT (DATE, t1.TransactionDate) 
																									WHEN	t1.TransactionEffectiveDate = CONVERT (DATE, t1.TransactionDate) AND t1.TransactionEffectiveDate > cal.CutOffDate THEN cal.EndDate 
																									ELSE	CONVERT (DATE, t1.AccountingBookDate)
																							END
																	ELSE	t1.AccountingBookDate
														END
		, TransactionType = tType.TransactionTypeDesc
		, MeasureName = 'WrittenPremium'
		, CurrencyCode = curr.CurrencyCode
		, TransactionAmount_OC = t2.TransactionAmount_OC
		, TransactionAmount = t2.TransactionAmount
		, PolicyTransactionId = t2.[PolicyTransactionId]
		, PolicyTransactionKey = t1.PolicyTransactionKey
		, DataVarInd = t1.DataVarInd
		, PolicyKey = p.PolicyKey
		, PolicyID = p.PolicyID
		, PolicyLevelsCompoundID = x.PolicyLevelsCompoundId
		, XrefPolicyLevelStartDate = x.StartDate
		, XrefPolicyLevelEndDate = X.EndDate
		, XrefDataVarInd = x.DataVarInd
		, DeprecatedDate = t1.DataVarIndDate 
		--, RunningTransactionAmount_OC = CASE WHEN ss.SourceSystemDesc LIKE 'BHSI%' THEN SUM(T2.[TransactionAmount_OC]) OVER(partition by policykey ORDER BY t1.TransactionDate ROWS UNBOUNDED PRECEDING) ELSE NULL END -- and tType.TransactionTypeDesc IN ('Renew', 'New', 'Rewrite', 'ReviseEffectiveDate', 'ReviseBind')
		--, RunningTransactionAmount    = CASE WHEN ss.SourceSystemDesc LIKE 'BHSI%' THEN SUM(T2.[TransactionAmount]) OVER(partition by policykey ORDER BY t1.TransactionDate ROWS UNBOUNDED PRECEDING) ELSE NULL END	   -- and tType.TransactionTypeDesc IN ('Renew', 'New', 'Rewrite', 'ReviseEffectiveDate', 'ReviseBind')
		--, Seq = RANK() OVER(partition by policykey ORDER BY transactionDate)
		, t1.TransactionDateDerived

	FROM
		YodilIDS_Warehouse.Policy.Policy p 

			JOIN YodilIDS_Warehouse.policy.XrefPolicyLevels x
				ON	x.PolicyId = p.PolicyId

			JOIN YodilIDS_Warehouse.[Policy].[PolicyTransactions] t1 
				ON	x.PolicyLevelsCompoundId = t1.PolicyLevelsCompoundId

			JOIN YodilIDS_Warehouse.[Policy].[PolicyTransactionDetails] t2
				ON	t2.PolicyTransactionId = t1.PolicyTransactionId

			LEFT JOIN YodilIDS_Warehouse.Shared.TransactionType tType
				ON	t1.TransactionTypeID = tType.TransactionTypeID

			LEFT JOIN YodilIDS_Warehouse.Shared.Currency curr
				ON	t1.OriginalCurrencyID = curr.CurrencyID

			LEFT JOIN YodilIDS_Warehouse.Control.SourceSystem ss
				ON	p.SourceSystemID = ss.SourceSystemID

			LEFT JOIN EDW..v_UnderwritingOffice uo
				ON	p.PolicyId = uo.PolicyId

			LEFT JOIN EDW..v_UnderwritingRegion ur
				ON	p.PolicyId = ur.PolicyId

			LEFT JOIN EDW..BHSI_ProcessDateCalendar cal
				ON	COALESCE (uo.Region, ur.Region) = cal.Region
				AND	CONVERT (VARCHAR (10), t1.TransactionEffectiveDate, 120) BETWEEN CONVERT (VARCHAR (10), cal.StartDate, 120) AND CONVERT (VARCHAR (10), cal.EndDate - 1, 120)
	WHERE
		x.EndDate = '9999-12-31'
		AND	p.PolicyType = 'P'
		AND	t2.MeasureName IN ('GrossPremium', 'WrittenPremium', 'GrossPremiumInUSD', 'WrittenPremiumInUSD')
		AND	p.PolicyNumber NOT LIKE '%MSL%'
		AND	COALESCE (x.DataVarInd, '') NOT IN ('R', 'C')
	 
	union all
	 select  MasterPolicyNumber, PolicyNumber, SourceSystemId, SourceSystemDesc, PolicyType, TransactionDate, TransactionEffectiveDate
		, TransactionIssueDate, AccountingBookDate, TransactionType, MeasureName, CurrencyCode, TransactionAmount_OC, TransactionAmount
		, PolicyTransactionId, PolicyTransactionKey, DataVarInd, PolicyKey, PolicyID, PolicyLevelsCompoundID, XrefPolicyLevelStartDate
		, XrefPolicyLevelEndDate, XrefDataVarInd, DeprecatedDate 
		, TransactionDateDerived
		from bhsI_temp_adjustments
	
	 

	) g
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	--update the PolicyLevelsCompoundID with correct value 
	--update a
	--set a.PolicyLevelsCompoundID = b.PolicyLevelsCompoundID
	--from #Temp_BHSI_Transaction a
	--join #Temp_BHSI_Transaction b 
	--on a.PolicyNumber = b.PolicyNumber
	--and a.MasterPolicyNumber = b.MasterPolicyNumber
	--where a.PolicyTransactionId=-1
	--and a.TransactionDate = b.TransactionDate
	--	and a.PolicyLevelsCompoundId=0

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
	select a.PolicyLevelsCompoundID , b.PolicyLevelsCompoundID, a.*
		from #Temp_BHSI_Transaction a
	join #Temp_BHSI_Transaction b 
	on a.PolicyNumber = b.PolicyNumber
	where a.PolicyTransactionId=-1
		and a.TransactionDate = b.TransactionDate
		and a.PolicyLevelsCompoundId=0
	select * from #Temp_BHSI_Transaction 	where policyid=110095704
	select * from bhsI_temp_adjustments
*/
update
	a
set
	PolicyLevelsCompoundId = b.PolicyLevelsCompoundId
	, PolicyId = b.PolicyId
	, SourceSystemId = b.SourceSystemId 
	, SourceSystemDesc = b.SourceSystemDesc 
	, TransactionDateDerived = b.TransactionDateDerived
--select a.*, b.PolicyLevelsCompoundId, b.policyid
from
	#temp_BHSI_Transaction a, #temp_BHSI_Transaction b
where
--	a.PolicyId = b.PolicyId
--	and	
	a.PolicyTransactionId = -1
	and	a.TransactionDate = b.TransactionDate
	and	b.PolicyTransactionId <> -1
	and	a.PolicyLevelsCompoundId = 0
	and	b.PolicyLevelsCompoundId <> 0
--	and	a.PolicyNumber like '%000211-03%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--select top 100 * from #Temp_BHSI_Transaction where PolicyNumber like '%000211-03%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Submission and Quote
INSERT	INTO	#Temp_BHSI_Transaction
	(
	MasterPolicyNumber
	, PolicyNumber
	, SourceSystemId
	, SourceSystemDesc
	, PolicyType
	, TransactionDate
	, TransactionEffectiveDate
	, TransactionIssueDate
	, AccountingBookDate
	, TransactionType
	, MeasureName
	, CurrencyCode
	, TransactionAmount_OC
	, TransactionAmount
	, PolicyTransactionId
	, PolicyTransactionKey
	, DataVarInd
	, PolicyKey
	, PolicyID
	, PolicyLevelsCompoundID
	, XrefPolicyLevelStartDate
	, XrefPolicyLevelEndDate
	, XrefDataVarInd
	, TransactionDateDerived
	)
SELECT	DISTINCT
	MasterPolicyNumber = p.MasterPolicyNumber
	, PolicyNumber = p.PolicyNumber
	, SourceSystemId = ss.SourceSystemId
	, SourceSystemDesc = ss.SourceSystemDesc
	, PolicyType = p.PolicyType
	, TransactionDate = nam.TransactionDate
	, TransactionEffectiveDate = P.EffectiveDate
	, TransactionIssueDate = NULL
	, AccountingBookDate = NULL
	, TransactionType = CASE	WHEN	 s.SourceStatusDesc IN ('Lost')		OR ssr.SourceStatusReasonDesc IN ('Lost')		THEN 'Lost'
													WHEN s.SourceStatusDesc IN ('DECLINED')		OR ssr.SourceStatusReasonDesc IN ('DECLINED')		THEN 'Decline'
													WHEN s.SourceStatusDesc LIKE 'Cancel%' OR ssr.SourceStatusReasonDesc LIKE 'Cancel%' THEN 'Cancellation'
													WHEN s.SourceStatusDesc in ('REVISEDQUOTE', 'QUOTED') OR ssr.SourceStatusReasonDesc IN ('REVISED QUOTE') THEN 'Quoted'
													WHEN s.SourceStatusDesc LIKE '%INDICATION%' OR ssr.SourceStatusReasonDesc LIKE '%INDICATION%' THEN 'Indicated'
													WHEN s.SourceStatusDesc = 'QUOTE' THEN 'Working'
													ELSE	ISNULL (s.SourceStatusDesc, ssr.SourceStatusReasonDesc)
									END
	, MeasureName  = 'WrittenPremium'
	, CurrencyCode = curr.CurrencyCode
	, TransactionAmount_OC = nam.MeasureAmount_OC
	, TransactionAmount = nam.MeasureAmount
	, PolicyTransactionID = NULL
	, PolicyTransactionKey = nam.PolicyTransactionKey
	, DataVarInd = nam.DataVarInd
	, PolicyKey = p.PolicyKey
	, PolicyID = p.PolicyID
	, PolicyLevelsCompoundId = x.PolicyLevelsCompoundID
	, xrefPolicyLevelStartDate = x.StartDate
	, xrefPolicyLevelEndDate = x.EndDate
	, XrefDataVarInd = x.DataVarInd
	, TransactionDateDerived = x.StartDate
FROM 
	YodilIDS_Warehouse.Policy.Policy p 

		JOIN YodilIDS_Warehouse.Policy.XrefPolicyLevels x
				on x.PolicyId = p.PolicyId

		JOIN YodilIDS_Warehouse.Policy.PolicyNonAdditiveMeasures nam
				on nam.PolicyLevelsCompoundId = x.PolicyLevelsCompoundId

		LEFT JOIN YodilIDS_Warehouse.Shared.Currency curr
			ON	nam.OriginalCurrencyID = curr.CurrencyID

		LEFT JOIN YodilIDS_Warehouse.[Control].SourceSystem ss
				ON	p.SourceSystemID = ss.SourceSystemID

	LEFT JOIN YodilIDS_Warehouse.[Shared].[SourceStatus] s
		ON	p.StatusId = s.SourceStatusId 

	LEFT JOIN YodilIDS_Warehouse.[Shared].[SourceStatusReason] ssr
		ON	p.StatusReasonId = ssr.SourceStatusReasonId 
WHERE
	x.EndDate = '9999-12-31'
	AND	nam.EndDate = '9999-12-31'
	AND	p.PolicyType <> 'P'
	AND	p.PolicyNumber NOT LIKE '%MSL%'
	AND	nam.MeasureName IN ('GrossPremium', 'WrittenPremium', 'GrossPremiumInUSD', 'WrittenPremiumInUSD')
	AND	COALESCE (x.DataVarInd, '') NOT IN ('R', 'C')
--	and		p.MasterPolicyNumber like '17-03-02-066559%'
-----------------------------------------------------------------------------------------------------------------------------------------------------
--select top 100 * from #Temp_BHSI_Transaction where PolicyNumber = '40-EPC-301765-01'
-----------------------------------------------------------------------------------------------------------------------------------------------------
-- INSERT MSL Policies
INSERT	INTO	#Temp_BHSI_Transaction
	(
	MasterPolicyNumber
	, PolicyNumber
	, SourceSystemId
	, SourceSystemDesc
	, PolicyType
	, TransactionDate
	, TransactionEffectiveDate
	, TransactionIssueDate
	, AccountingBookDate
	, TransactionType
	, MeasureName
	, CurrencyCode
	, TransactionAmount_OC
	, TransactionAmount
	, PolicyTransactionId
	, PolicyTransactionKey
	, DataVarInd
	, PolicyKey
	, PolicyID
	, PolicyLevelsCompoundID
	, XrefPolicyLevelStartDate
	, XrefPolicyLevelEndDate
	, XrefDataVarInd
	, DeprecatedDate
	, TransactionDateDerived
	)
SELECT 
	MasterPolicyNumber= groupPolicy.GroupMasterPolicyNumber 
	, PolicyNumber = groupPolicy.GroupPolicyNumber 
	, SourceSystemId = p.SourceSystemId 
	, SourceSystemDesc = ss.SourceSystemDesc
	, PolicyType = p.PolicyType
	, TransactionDate = t1.TransactionDate														-- CONVERT (DATETIME, CONVERT (VARCHAR (10), t1.TransactionDate, 120)
	, TransactionEffectiveDate = t1.TransactionEffectiveDate
	, TransactionIssueDate = t1.TransactionIssueDate
	, AccountingBookDate = t1.AccountingBookDate
	, TransactionType = tType.TransactionTypeDesc
	, MeasureName = 'WrittenPremium'
	, CurrencyCode = curr.CurrencyCode 
	, TransactionAmount_OC = t2.TransactionAmount_OC
	, TransactionAmount = t2.TransactionAmount
	, PolicyTransactionId = t2.[PolicyTransactionId]
	, PolicyTransactionKey = t1.PolicyTransactionKey
	, DataVarInd = t1.DataVarInd
	, PolicyKey = p.PolicyKey
	, PolicyID = p.PolicyID
	, PolicyLevelsCompoundID = x.PolicyLevelsCompoundId
	, XrefPolicyLevelStartDate = x.StartDate
	, XrefPolicyLevelEndDate = X.EndDate
	, XrefDataVarInd = x.DataVarInd
	, DeprecatedDate = t1.DataVarIndDate 
	, TransactionDateDerived = t1.TransactionDateDerived
FROM
	YodilIDS_Warehouse.Policy.Policy p 

		JOIN YodilIDS_Warehouse.policy.XrefPolicyLevels x
			ON	x.PolicyId = p.PolicyId

		JOIN YodilIDS_Warehouse.[Policy].[PolicyTransactions] t1 
			ON	x.PolicyLevelsCompoundId = t1.PolicyLevelsCompoundId

		JOIN YodilIDS_Warehouse.[Policy].[PolicyTransactionDetails] t2
			ON	t2.PolicyTransactionId = t1.PolicyTransactionId

		LEFT JOIN YodilIDS_Warehouse.Shared.TransactionType tType
			ON	t1.TransactionTypeID = tType.TransactionTypeID

		LEFT JOIN YodilIDS_Warehouse.Shared.Currency curr
			ON	t1.OriginalCurrencyID = curr.CurrencyID

		LEFT JOIN YodilIDS_Warehouse.Control.SourceSystem ss
			ON	p.SourceSystemID = ss.SourceSystemID

		JOIN	(
					SELECT	DISTINCT 
							MasterPolicyNumber				= a.MasterPolicyNumber
							, PolicyNumber							= a.PolicyNumber
							, GroupMasterPolicyNumber = a.MasterPolicyNumber
							, GroupPolicyNumber				= a.PolicyNumber
						FROM
							YodilIDS_Warehouse.Policy.Policy a
						WHERE
							a.EndDate = '9999-12-31'
							AND	a.PolicyNumber LIKE '%MSL%'
							AND	a.PolicyNumber NOT LIKE '%NT/APP%'

						UNION

						SELECT	DISTINCT 
							MasterPolicyNumber				= a.MasterPolicyNumber
							, PolicyNumber							= a.PolicyNumber
							, GroupMasterPolicyNumber = ISNULL (b.MasterPolicyNumber, a.MasterPolicyNumber)
							, GroupPolicyNumber				= ISNULL (b.PolicyNumber, a.PolicyNumber)
						FROM
							YodilIDS_Warehouse.Policy.Policy a
								LEFT JOIN YodilIDS_Warehouse.Policy.Policy b
									ON	LEFT (a.MasterPolicyNumber, LEN (a.MasterPolicyNumber) - 3) = LEFT (b.MasterPolicyNumber, LEN (b.MasterPolicyNumber) - 3)
									AND	b.PolicyNumber NOT LIKE '%NT/APP%'
						WHERE
							a.EndDate = '9999-12-31'
							AND	a.PolicyNumber LIKE '%MSL%'
							AND	a.PolicyNumber LIKE '%NT/APP%'
						) groupPolicy
					ON	p.MasterPolicyNumber = groupPolicy.MasterPolicyNumber 
					AND	p.PolicyNumber = groupPolicy.PolicyNumber 
WHERE
	x.EndDate = '9999-12-31'
	AND	p.PolicyType = 'P'
	AND	p.PolicyNumber LIKE '%MSL%'
	AND	t2.MeasureName IN ('GrossPremium', 'WrittenPremium', 'GrossPremiumInUSD', 'WrittenPremiumInUSD')
	AND	COALESCE (x.DataVarInd, '') NOT IN ('R', 'C')
-- and p.policynumber = '42-UMO-100329-03'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- For ODS Sub and Quote, keep the latest transaction and delete older ones when more than one transaction
-- select top 100 * from #Temp_BHSI_Transaction where policytype <> 'p' and sourcesystemdesc = 'ods' and masterpolicynumber like '17-03-02-066559%'
DELETE
	t
FROM
	#Temp_BHSI_Transaction t
		JOIN (
						SELECT
							PolicyNumber
							, MasterPolicyNumber
							, Cnt = COUNT (*)
							, xRefPolicyLevelStartDate = MAX (xRefPolicyLevelStartDate)
						FROM
							#Temp_BHSI_Transaction 
						WHERE
							SourceSystemDesc = 'ODS'
							AND	PolicyType <> 'P'
						GROUP BY
							PolicyNumber
							, MasterPolicyNumber
						HAVING
							COUNT (*) > 1
					) s

			ON	
				t.PolicyNumber = s.PolicyNumber
				AND	t.MasterPolicyNumber = s.MasterPolicyNumber
WHERE
	t.xRefPolicyLevelStartDate < s.xRefPolicyLevelStartDate
	AND	t.SourceSystemDesc = 'ODS'
	AND	t.PolicyType <> 'P'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
 select count (*) from v_Premium
 select sourcesystemdesc, policytype, measurename, amount = sum (transactionamount_oc) from #Temp_BHSI_Transaction group by sourcesystemdesc, policytype, measurename order by 1, 2, 3
 select sourcesystemdesc, policytype, measurename, amount = sum (transactionamount_oc) from v_premium group by sourcesystemdesc, policytype, measurename order by 1, 2, 3
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Insert Shred submissions/quotes that do not have any premium, thus did not get into NonAdditiveMeasure table
INSERT	INTO	#Temp_BHSI_Transaction
	(MasterPolicyNumber, PolicyNumber, SourceSystemId, SourceSystemDesc, PolicyType, TransactionDate, TransactionEffectiveDate, TransactionIssueDate, AccountingBookDate, TransactionType
	, MeasureName, CurrencyCode, TransactionAmount_OC, TransactionAmount, PolicyTransactionID, PolicyTransactionKey, DataVarInd, PolicyKey, PolicyID
--	, PolicyLevelsCompoundId, xrefPolicyLevelStartDate, xrefPolicyLevelEndDate, XrefDataVarInd
	, TransactionDateDerived
	)
SELECT	DISTINCT
	MasterPolicyNumber = p.MasterPolicyNumber
	, PolicyNumber = p.PolicyNumber
	, SourceSystemId = ss.SourceSystemId
	, SourceSystemDesc = ss.SourceSystemDesc
	, PolicyType = p.PolicyType
	, TransactionDate = NULL
	, TransactionEffectiveDate = NULL
	, TransactionIssueDate = NULL
	, AccountingBookDate = NULL
	, TransactionType = CASE	WHEN	 s.SourceStatusDesc IN ('Lost')		OR ssr.SourceStatusReasonDesc IN ('Lost')		THEN 'Lost'
													WHEN s.SourceStatusDesc IN ('DECLINED')		OR ssr.SourceStatusReasonDesc IN ('DECLINED')		THEN 'Decline'
													WHEN s.SourceStatusDesc LIKE 'Cancel%' OR ssr.SourceStatusReasonDesc LIKE 'Cancel%' THEN 'Cancellation'
													WHEN s.SourceStatusDesc in ('REVISEDQUOTE', 'QUOTED') OR ssr.SourceStatusReasonDesc IN ('REVISED QUOTE') THEN 'Quoted'
													WHEN s.SourceStatusDesc LIKE '%INDICATION%' OR ssr.SourceStatusReasonDesc LIKE '%INDICATION%' THEN 'Indicated'
													WHEN s.SourceStatusDesc = 'QUOTE' THEN 'Working'
													ELSE	ISNULL (s.SourceStatusDesc, ssr.SourceStatusReasonDesc)
									END
	, MeasureName  = 'WrittenPremium'
	, CurrencyCode = NULL
	, TransactionAmount_OC = 0
	, TransactionAmount = 0
	, PolicyTransactionID = NULL
	, PolicyTransactionKey = NULL
	, DataVarInd = NULL
	, PolicyKey = p.PolicyKey
	, PolicyID = p.PolicyID
--	, PolicyLevelsCompoundId = x.PolicyLevelsCompoundId 
--	, xrefPolicyLevelStartDate = x.StartDate
--	, xrefPolicyLevelEndDate = x.EndDate
--	, XrefDataVarInd = x.DataVarInd
	, TransactionDateDerived = p.StartDate
FROM 
	YodilIDS_Warehouse.Policy.Policy p 

--		JOIN YodilIDS_Warehouse.Policy.XrefPolicyLevels x
--			ON x.PolicyId = p.PolicyId

		LEFT JOIN YodilIDS_Warehouse.[Control].SourceSystem ss
			ON	p.SourceSystemID = ss.SourceSystemID

		LEFT JOIN YodilIDS_Warehouse.[Shared].[SourceStatus] s
			ON	p.StatusId = s.SourceStatusId 

		LEFT JOIN YodilIDS_Warehouse.[Shared].[SourceStatusReason] ssr
			ON	p.StatusReasonId = ssr.SourceStatusReasonId 
WHERE
--	x.EndDate = '9999-12-31'
--	AND	
	p.EndDate = '9999-12-31'
	AND	p.PolicyType <> 'P'
	AND	p.PolicyNumber NOT LIKE '%MSL%'
	AND	p.PolicyNumber NOT IN (SELECT DISTINCT PolicyNumber FROM #Temp_BHSI_Transaction WHERE SourceSystemDesc = 'BHSI Quote' AND PolicyType <> 'P')
	AND	ss.SourceSystemDesc = 'BHSI Quote'
--	AND	COALESCE (x.DataVarInd, '') NOT IN ('R', 'C')
--	and		p.PolicyNumber in ('15-05-02-010744', '15-06-03-012600', '15-08-02-016604','16-01-03-026792','16-01-03-026834','16-01-03-026847','16-01-03-026891')
--	and		p.PolicyNumber in ('16-12-03-049136')
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
select top 100 * from #Temp_BHSI_Transaction where PolicyNumber = '43-XPL-150850-01' and PolicyId in  (61592044, 55596528)
select PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemId, PolicyTransactionId, PolicyLevelsCompoundId, count (*) from #Temp_BHSI_Transaction group by PolicyId, PolicyNumber, MasterPolicyNumber, SourceSystemId, PolicyTransactionId, PolicyLevelsCompoundId having count (*) > 1
select transactiondate, count (*) from #Temp_BHSI_Transaction group by transactiondate order by 1
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Get AsOfPolicyId
-- select top 100 * from #Temp_BHSI_Transaction
--UPDATE
--	t
--SET
--	AsOfPolicyId = COALESCE (p.PolicyId, t.PolicyId)
----	AsOfPolicyId = p.PolicyId
--FROM
--	#Temp_BHSI_Transaction t, YodilIDS_Warehouse.Policy.Policy p
--WHERE
--	t.PolicyKey = p.PolicyKey 
----	t.PolicyNumber = p.PolicyNumber 
----	AND	t.MasterPolicyNumber = p.MasterPolicyNumber 
--	AND	t.PolicyType = p.PolicyType 
--	AND	t.TransactionDate >= p.StartDate 
--	AND	t.TransactionDate < p.EndDate 

UPDATE
	t
SET
	AsOfPolicyId = COALESCE (p.PolicyId, t.PolicyId)
--	AsOfPolicyId = p.PolicyId
FROM
	#Temp_BHSI_Transaction t, YodilIDS_Warehouse.Policy.Policy p
WHERE
	t.PolicyKey = p.PolicyKey 
--	t.PolicyNumber = p.PolicyNumber 
--	AND	t.MasterPolicyNumber = p.MasterPolicyNumber 
	AND	t.PolicyType = p.PolicyType 
	AND	(t.TransactionDateDerived = p.StartDate 
		OR	(t.TransactionDate >= p.StartDate 
		AND	t.TransactionDate < p.EndDate ))

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
update #Temp_BHSI_Transaction
set AsOfPolicyId = PolicyId
where AsOfPolicyId is null
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Now assign TransactionDate and TransactionIssueDate for NULL TransactionDate entries
UPDATE
	t
SET
	TransactionDate = d.TransactionDate 
	, TransactionEffectiveDate = d.EffectiveDate 
--select count (*)
FROM
	#Temp_BHSI_Transaction t, (SELECT	DISTINCT PolicyLevelsCompoundId, TransactionDate, EffectiveDate FROM YodilIDS_Warehouse.Policy.PolicyNonAdditiveMeasures ) d --WHERE EndDate = '9999-12-31') d
WHERE
	t.PolicyLevelsCompoundId = d.PolicyLevelsCompoundId 
	AND	t.TransactionDate IS NULL
--	and		t.PolicyNumber in ('15-05-02-010744', '15-06-03-012600', '15-08-02-016604','16-01-03-026792','16-01-03-026834','16-01-03-026847','16-01-03-026891')
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 * from #Temp_BHSI_Transaction where policynumber = '40-PRI-302594-01' and policytype = 'p'
--select top 100 * from #Temp_BHSI_Transaction where policynumber = '47-SUR-300007-01' and MasterPolicyNumber like '%14'
-- select top 100 * from edw..v_commissionpercent where policynumber = '47-SUR-300007-01' and MasterPolicyNumber like '%14'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Region
UPDATE
	t
SET
	Region = CASE WHEN ISNULL (uo.Region, '') = '' AND ISNULL (ur.Region, '') = '' THEN 'North America'
								ELSE	COALESCE (uo.Region, ur.Region, 'North America')
					END
FROM
	#Temp_BHSI_Transaction t
		LEFT JOIN EDW..v_UnderwritingOffice uo
			ON	t.PolicyId = uo.PolicyId
		LEFT JOIN EDW..v_UnderwritingRegion ur
			ON	t.PolicyId = ur.PolicyId
/**
	Ignoring Deprecated Issue Policy Transaction from Source
**/
DELETE from #Temp_BHSI_Transaction
where DataVarInd = 'D' and TransactionType like 'Issue%Policy'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 150806
-- select top 100 * from #Temp_BHSI_Transaction where policynumber like '%000211-03%' and measurename = 'writtenpremium' and policytype = 'P' and datavarind is null
-- select top 100 * from [dbo].[BHSI_ProcessDateCalendar]
-- select region, count (*) from #temp_bhsi_transaction group by region
-- select * from #temp_bhsi_transaction where region = ''
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 2nd Temp table to store both system entries and manual adjustment entries
DROP TABLE IF EXISTS #temp_Trans2

SELECT
	[PolicyId]
	, [AsOfPolicyId] 
	,[PolicyNumber]
	,[MasterPolicyNumber]
	,[SourceSystemId]
	,[SourceSystemDesc]
	,[PolicyType]
	,[TransactionDate]
	,[TransactionEffectiveDate]
	,[TransactionIssueDate]
	,[AccountingBookDate]
	,[TransactionType]
	,[MeasureName]
	,[CurrencyCode]
	,[TransactionAmount_OC] = case when TransactionType IN ('Renew', 'New', 'Rewrite', 'ReviseEffectiveDate', 'ReviseBind') and PolicyTransactionId>0 then RunningTransactionAmount_OC else TransactionAmount_OC END
	,[TransactionAmount] = case    when TransactionType IN ('Renew', 'New', 'Rewrite', 'ReviseEffectiveDate', 'ReviseBind') and PolicyTransactionId>0 then RunningTransactionAmount    else TransactionAmount END
	,[PolicyTransactionId]
	,[PolicyTransactionKey]
	,[DataVarInd]
	,[PolicyKey]
	,[PolicyLevelsCompoundID]
	,[XrefPolicyLevelStartDate]
	,[XrefPolicyLevelEndDate]
	,[XrefDataVarInd]
	,[DeprecatedDate]
	,[Src_TransactionAmount_OC] = TransactionAmount_OC
	,[Src_TransactionAmount] = TransactionAmount
	,[RunningTransactionAmount_OC]
	,[RunningTransactionAmount]
	,[Seq]
	,[Region]
	, [RootDctId] = CASE	WHEN SourceSystemDesc LIKE 'BHSI%' AND ISNULL (PolicyTransactionKey, '') <> '' THEN LEFT (PolicyTransactionKey, CHARINDEX ('||', PolicyTransactionKey) - 1)
							ELSE	0
				END
	, [HistoryId] = CASE	WHEN SourceSystemDesc LIKE 'BHSI%' AND ISNULL (PolicyTransactionKey, '') <> '' THEN LEFT (RIGHT (PolicyTransactionKey, LEN (PolicyTransactionKey) - CHARINDEX ('||', PolicyTransactionKey) - 1), CHARINDEX ('||', RIGHT (PolicyTransactionKey, LEN (PolicyTransactionKey) - CHARINDEX ('||', PolicyTransactionKey) - 1)) -1)
							ELSE	0
				END
	, [CurrentStatus] = CASE	WHEN	 TransactionType IN ('New', 'Renew', 'ReviseEffectiveDate', 'Rewrite', 'Adj - Renew') THEN 'Bound'
								WHEN	 TransactionType IN ('Cancel', 'CancelBind', 'Adj - Cancel', 'Adj - CancelBind') THEN 'Cancellation'
								WHEN	 TransactionType IN ('Endorse', 'Adj - Endorse') THEN 'Endorsement'
								WHEN	 TransactionType IN ('Reinstate', 'Adj - Reinstate') THEN 'Reinstated'
								WHEN	 TransactionType IN ('IssuePolicy', 'Adj - IssuePolicy') THEN 'Issue'
								WHEN	 TransactionType IN ('ReviseBind', 'Adj - ReviseBind') THEN 'Re-Entry'
								WHEN	 TransactionType IN ('Reversal') THEN 'Reversal'
								ELSE TransactionType 
						END
	,[ProcessDate] = CONVERT (DATETIME, NULL)
	,[OldTransactionDate] = CONVERT (DATETIME2, NULL)
	,TransactionDateDerived
INTO
	#temp_Trans2
FROM
	#Temp_BHSI_Transaction

-- Now Insert Adjustment entries for ReviseBind and Deprecated Transactions
INSERT INTO #temp_Trans2 
	([PolicyId], [AsOfPolicyId] , [PolicyNumber], [MasterPolicyNumber], [SourceSystemId], [SourceSystemDesc], [PolicyType], [TransactionDate]	, [TransactionEffectiveDate]
	, [TransactionIssueDate], [AccountingBookDate], [TransactionType], [MeasureName], [CurrencyCode], [TransactionAmount_OC], [TransactionAmount], [PolicyTransactionId]
	, [PolicyTransactionKey], [DataVarInd], [PolicyKey], [PolicyLevelsCompoundID], [XrefPolicyLevelStartDate], [XrefPolicyLevelEndDate], [XrefDataVarInd], [DeprecatedDate]
	, [Src_TransactionAmount_OC], [Src_TransactionAmount], [RunningTransactionAmount_OC],[RunningTransactionAmount], [Seq], [Region], RootDctId, HistoryId, CurrentStatus
	, [OldTransactionDate], TransactionDateDerived)
SELECT 
	T1.[PolicyId]
	, T1.[AsOfPolicyId] 
	,[PolicyNumber]                     = T1.[PolicyNumber]
	,[MasterPolicyNumber]               = T1.[MasterPolicyNumber]
	,[SourceSystemId]                   = T1.[SourceSystemId]
	,[SourceSystemDesc]                 = T1.[SourceSystemDesc]
	,[PolicyType]                       = T1.[PolicyType]
	,[TransactionDate]                  = case T1.datavarInd when 'D' then T1.DeprecatedDate else T2.[TransactionDate] END
	,[TransactionEffectiveDate]         = T1.[TransactionEffectiveDate]
	,[TransactionIssueDate]             = T1.[TransactionIssueDate]
	,[AccountingBookDate]               = T2.[AccountingBookDate]
	--,[TransactionType]                  = case T1.datavarInd when 'D' then 'Adj - '+ T1.TransactionType else 'Reversal' end
	,[TransactionType]                  = case when T1.datavarInd = 'D' and T2.TransactionType != 'ReviseBind' then 'Adj - '+ T1.TransactionType else 'Reversal' end
	,T1.[MeasureName]
	,T1.[CurrencyCode]
	--,[TransactionAmount_OC]             = - case T1.datavarInd when 'D' then T1.TransactionAmount_OC else T1.RunningTransactionAmount_OC END 
	--,[TransactionAmount]                = - case T1.datavarInd when 'D' then T1.TransactionAmount else T1.RunningTransactionAmount END 
	,[TransactionAmount_OC]             = - case when T1.datavarInd = 'D' and T2.TransactionType != 'ReviseBind' then T1.TransactionAmount_OC else T1.RunningTransactionAmount_OC END 
	,[TransactionAmount]                = - case when T1.datavarInd = 'D' and T2.TransactionType != 'ReviseBind' then T1.TransactionAmount else T1.RunningTransactionAmount END 
	,T1.[PolicyTransactionId]
	,T1.[PolicyTransactionKey]
	,T1.[DataVarInd]
	,T1.[PolicyKey]
	,T1.[PolicyLevelsCompoundID]
	,T1.[XrefPolicyLevelStartDate]
	,T1.[XrefPolicyLevelEndDate]
	,T1.[XrefDataVarInd]
	,T1.[DeprecatedDate]
	,Src_TransactionAmount_OC = case T1.datavarInd when 'D' then T1.TransactionAmount_OC * -1 else 0 end
	,Src_TransactionAmount = case T1.datavarInd when 'D' then T1.TransactionAmount  * -1 else 0 end
	,T1.[RunningTransactionAmount_OC]
	,T1.[RunningTransactionAmount]
	,T1.[Seq]
	,T1.[Region]
	, CASE	WHEN T1.SourceSystemDesc LIKE 'BHSI%' AND ISNULL (T1.PolicyTransactionKey, '') <> '' THEN LEFT (T1.PolicyTransactionKey, CHARINDEX ('||', T1.PolicyTransactionKey) - 1)
									ELSE	0
						END
	, HistoryId = CASE	WHEN T1.SourceSystemDesc LIKE 'BHSI%' AND ISNULL (T1.PolicyTransactionKey, '') <> '' 
		THEN LEFT (RIGHT (T1.PolicyTransactionKey, LEN (T1.PolicyTransactionKey) - CHARINDEX ('||', T1.PolicyTransactionKey) - 1), CHARINDEX ('||', RIGHT (T1.PolicyTransactionKey, LEN (T1.PolicyTransactionKey) - CHARINDEX ('||', T1.PolicyTransactionKey) - 1)) -1)
								ELSE	0
						END
	,CurrentStatus = CASE	WHEN	 T2.TransactionType IN ('ReviseBind', 'Adj - ReviseBind') THEN 'Re-Entry'
										WHEN	 T1.TransactionType IN ('New', 'Renew', 'ReviseEffectiveDate', 'Rewrite', 'Adj - Renew') THEN 'Bound'
										WHEN	 T1.TransactionType IN ('Cancel', 'CancelBind', 'Adj - Cancel', 'Adj - CancelBind') THEN 'Cancellation'
										WHEN	 T1.TransactionType IN ('Endorse', 'Adj - Endorse') THEN 'Endorsement'
										WHEN	 T1.TransactionType IN ('Reinstate', 'Adj - Reinstate') THEN 'Reinstated'
										WHEN	 T1.TransactionType IN ('IssuePolicy', 'Adj - IssuePolicy') THEN 'Issue'
										WHEN	 T1.TransactionType IN ('Reversal') THEN 'Reversal'
										ELSE T1.TransactionType 
								END
	, [OldTransactionDate] = T1.TransactionDate
	,T1.TransactionDateDerived
FROM 
	#Temp_BHSI_Transaction T1
		JOIN #Temp_BHSI_Transaction T2 
			ON T1.PolicyKey = T2.PolicyKey 
			AND T1.measureName = T2.MeasureName 
WHERE
	((T2.TransactionType = 'ReviseBind'
			AND T1.Seq + 1 = T2.Seq)
	 OR (COALESCE(T1.[DataVarInd], '') = 'D' and t1.Seq = T2.Seq and T1.TransactionType != 'ReviseBind'))
--	 and t1.measurename like '%prem%'
	 --and t1.PolicyNumber = '42-XSF-100266-03'
	 --and t1.PolicyNumber = '42-UMO-100191-02'


/**
	Calculating Premium excluding terrorism 
**/
/** Excluding Terrorism calculation
DROP TABLE IF EXISTS #GrossPremiumExclTerrorism
SELECT DISTINCT nam.PolicyID, nam.PolicyNumber, nam.TransactionDate
	, BHSIGrossPolicyPremium_ExcTerrorism = CAST(nam.BHSIGrossPolicyPremium_ExcTerrorism as decimal)
INTO #GrossPremiumExclTerrorism
FROM EDW.dbo.v_NonAdditiveMeasure nam
	JOIN EDW.dbo.v_ProductLine PL ON nam.PolicyID = PL.PolicyID 
WHERE PL.ProductLine = 'Property' AND COALESCE(nam.BHSIGrossPolicyPremium_ExcTerrorism,0) > 0
**/

/**
	Calculating Layer commission
**/

DROP TABLE IF EXISTS #LayerCommision -- WHERE PolicyNumber in ('42-PRP-301276-02', '42-PRP-000059-04')
SELECT
	commPct.AsOfPolicyId, commPct.PolicyNumber, commPct.MasterPolicyNumber, commPct.SourceSystemDesc
	, LayerPremium_OC = SUM (LayerPremium_OC)
	, CommissionAmount_OC = SUM (CommissionAmount_OC)
--	, CommissionAmount = SUM (CommissionAmount)
	, CommPct = ABS(CASE	WHEN	 SUM (LayerPremium_OC) = 0 THEN 0
									ELSE		SUM (CommissionAmount_OC) / SUM (LayerPremium_OC)
						END)
		, TransactionType
	INTO #LayerCommision
FROM
	(
	SELECT
		l.AsOfPolicyId, l.PolicyNumber, l.MasterPolicyNumber, l.SourceSystemDesc
		, LayerPremium_OC = BHSIGrossLayerPremium, L.LayerCommission
		, CommissionAmount_OC = l.BHSIGrossLayerPremium *l.LayerCommission * (case Tr.TransactionType when 'Reversal' then -1 else 1 end)
		, tr.TransactionType
	--	, CommissionAmount = l.LayerPremium *l.LayerCommission
	FROM #temp_Trans2 Tr
		JOIN EDW.dbo.v_Layer_ASOF l ON l.AsOfPolicyId = Tr.AsOfPolicyId and Tr.TransactionType in ('Renew', 'New', 'Rewrite', 'ReviseEffectiveDate', 'ReviseBind', 'Reversal') 
		
		JOIN EDW.dbo.v_ProductLine_ASOF PL
			ON l.asofPolicyId = pl.asofPolicyId and l.SourceSystemDesc like 'BHSI %' and PL.ProductLine = 'Property'
			WHERE l.PolicyNumber in ('42-PRP-301276-02', '42-PRP-000059-04')
	) commPct
GROUP BY 
	commPct.AsOfPolicyId, commPct.PolicyNumber, commPct.MasterPolicyNumber, commPct.SourceSystemDesc
		, TransactionType
HAVING SUM (LayerPremium_OC) > 0
	 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 161464

--select * from #GrossPremiumExclTerrorism where policynumber = '42-PRP-301189-02'

-- select top 100 * from #temp_Trans2 where policynumber = '40-PRI-302594-01' and policytype = 'p' and MeasureName like 'c%' order by seq, TransactionDate, TransactionType
-- select top 100 * from #temp_Trans2 where policynumber = '42-XSF-100266-03' and policytype = 'p' and MeasureName like 'WRI%' order by seq, TransactionDate, TransactionType
-- select top 100 * from #temp_Trans2 where policynumber = '42-EMC-303282-01' and policytype = 'p' and MeasureName like 'WRI%' order by seq, TransactionDate, TransactionType
-- select top 100 * from #temp_Trans2 where policynumber like '%000211-03%' and policytype = 'p' order by seq, TransactionDate, TransactionType
-- select * from edw..v_CommissionPercent where policynumber = '40-PRI-302594-01' and sourcesystemdesc like '%policy' order by 
-- select count (*) from #Temp_Trans2  where policynumber = '47-XSF-302519-01' and measurename = 'writtenpremium' order by transactiondate
-- select distinct TransactionType from #Temp_BHSI_Transaction where sourcesystemdesc like 'bhsi p%' order by 1
-- select * from #temp_Trans2 t where TransactionAmount_OC <> TransactionAmount AND	t.SourceSystemDesc LIKE 'BHSI%'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Commission
-- For Shred: Commission Amount = Premium * CommissionPercent 
-- Based on PolicyId, SourceSystemId, PolicyLevelCompoundKey and PolicyTransactionKey
INSERT INTO		#temp_Trans2
	(MasterPolicyNumber, PolicyNumber, SourceSystemId, SourceSystemDesc, PolicyType, TransactionDate, TransactionEffectiveDate, TransactionIssueDate, AccountingBookDate
	, TransactionType, MeasureName, CurrencyCode, TransactionAmount_OC, TransactionAmount, PolicyTransactionID, PolicyTransactionKey, DataVarInd, PolicyKey, PolicyID, AsOfPolicyId 
	, PolicyLevelsCompoundId, xrefPolicyLevelStartDate, xrefPolicyLevelEndDate, XrefDataVarInd, DeprecatedDate, Src_TransactionAmount_OC, Src_TransactionAmount
	, RunningTransactionAmount_OC, RunningTransactionAmount, Seq, Region, CurrentStatus, ProcessDate, OldTransactionDate, RootDctId, HistoryId)
SELECT 
	t.MasterPolicyNumber, t.PolicyNumber, t.SourceSystemId, t.SourceSystemDesc, t.PolicyType, t.TransactionDate, t.TransactionEffectiveDate, t.TransactionIssueDate
	, t.AccountingBookDate, t.TransactionType
	, MeasureName = 'Commission'
	, t.CurrencyCode

	--, TransactionAmount_OC = t.TransactionAmount_OC * c.CommissionPercent
	--, TransactionAmount = t.TransactionAmount * c.CommissionPercent 
	/**
	, TransactionAmount_OC = case when TransactionType in ('Renew', 'New', 'Rewrite', 'ReviseEffectiveDate', 'ReviseBind', 'Reversal') 
									and coalesce(PET.BHSIGrossPolicyPremium_ExcTerrorism, 0) < abs(t.TransactionAmount_OC)
								then coalesce( (case TransactionType when 'Reversal' then -1 else 1 end) * PET.BHSIGrossPolicyPremium_ExcTerrorism, t.TransactionAmount_OC) 
							else t.TransactionAmount_OC END * c.CommissionPercent
	, TransactionAmount = case when TransactionType in ('Renew', 'New', 'Rewrite', 'ReviseEffectiveDate', 'ReviseBind', 'Reversal') 
									and coalesce(PET.BHSIGrossPolicyPremium_ExcTerrorism, 0) < abs(t.TransactionAmount)
								then coalesce( (case TransactionType when 'Reversal' then -1 else 1 end) * PET.BHSIGrossPolicyPremium_ExcTerrorism, t.TransactionAmount) 
							else t.TransactionAmount END * c.CommissionPercent  **/
	--, Terrorpremium = case when TransactionType in ('Renew', 'New', 'Rewrite', 'ReviseEffectiveDate', 'ReviseBind') 
	--							then coalesce(PET.BHSIGrossPolicyPremium_ExcTerrorism, t.TransactionAmount) 
	--						else t.TransactionAmount END

	, TransactionAmount_OC = COALESCE(LyComm.CommissionAmount_OC, t.TransactionAmount_OC * c.CommissionPercent)
	, TransactionAmount = COALESCE(LyComm.CommissionAmount_OC, t.TransactionAmount * c.CommissionPercent )

	--, Premium = t.TransactionAmount
	, t.PolicyTransactionID, t.PolicyTransactionKey, t.DataVarInd, t.PolicyKey
	, t.PolicyID, t.AsOfPolicyId 
	, t.PolicyLevelsCompoundId, t.xrefPolicyLevelStartDate
	, t.xrefPolicyLevelEndDate, t.XrefDataVarInd, t.DeprecatedDate 
	/**  TODO revisit for terrorism premium   **/
	, Src_TransactionAmount_OC = t.Src_TransactionAmount_OC * c.CommissionPercent
	, Src_TransactionAmount = t.Src_TransactionAmount * c.CommissionPercent
	, RunningTransactionAmount_OC = t.RunningTransactionAmount_OC * c.CommissionPercent
	, RunningTransactionAmount    = t.RunningTransactionAmount * c.CommissionPercent
--	, RunningTransactionAmount_OC = CASE WHEN t.Seq = 1 THEN t.Src_TransactionAmount_OC * c.CommissionPercent ELSE 0 END
--	, RunningTransactionAmount    = CASE WHEN t.Seq = 1 THEN t.Src_TransactionAmount * c.CommissionPercent ELSE 0 END
	, Seq = t.Seq
	, Region = t.Region 
	, CurrentStatus = t.CurrentStatus 
	, ProcessDate = t.ProcessDate
	, OldTransactionDate = t.OldTransactionDate 
	, RootDctId = t.RootDctId
	, HistoryId = t.HistoryId 
FROM
	#temp_Trans2 t
	JOIN EDW..v_CommissionPercent_layer c ON 
			t.PolicyId = c.PolicyId 
			AND	t.SourceSystemId = c.SourceSystemId
			AND	coalesce(t.oldTransactionDate, t.TransactionDate) = c.TransactionDate 
			--AND	t.PolicyLevelsCompoundID = c.PolicyLevelsCompoundId 
			--AND	t.PolicyTransactionKey = c.PolicyTransactionKey
			AND	t.SourceSystemDesc LIKE 'BHSI%'
			--and t.PolicyNumber = '42-PRP-301189-02'
	--LEFT JOIN #GrossPremiumExclTerrorism PET 
	--		ON t.Policyid = PET.Policyid and coalesce(t.oldTransactionDate, t.TransactionDate) = PET.TransactionDate
	LEFT JOIN #LayerCommision LyComm 
		ON t.AsOfPolicyId = LyComm.AsOfPolicyId
			and t.TransactionType = LyComm.TransactionType
			--and t.CurrencyCode != 'USD'
--WHERE
--	--t.PolicyId = c.PolicyId 
--	--and t.asofPolicyid = PET.asofPolicyid 
--	AND	t.SourceSystemId = c.SourceSystemId
--	AND	t.PolicyLevelsCompoundID = c.PolicyLevelsCompoundId 
--	AND	t.PolicyTransactionKey = c.PolicyTransactionKey
--	AND	t.SourceSystemDesc LIKE 'BHSI%'
--	and t.PolicyNumber = '42-PRP-000291-03' order by t.seq, t.transactiondate, t.transactiontype
--	and		t.PolicyNumber = '40-PRI-302594-01'
--	order by t.Seq , t.transactiondate
--	and t.PolicyTransactionKey = '35598||64091||2016-05-23 15:08:16.8200000'

-- For ODS: Get data from PolicyTransaction tables
INSERT INTO		#temp_Trans2 --#Temp_BHSI_Transaction 
	(MasterPolicyNumber, PolicyNumber, SourceSystemId, SourceSystemDesc, PolicyType, TransactionDate, TransactionEffectiveDate, TransactionIssueDate, AccountingBookDate, TransactionType
	, MeasureName, CurrencyCode, TransactionAmount_OC, TransactionAmount, Src_TransactionAmount_OC, Src_TransactionAmount, PolicyTransactionID, PolicyTransactionKey
	, DataVarInd, PolicyKey, PolicyID, AsOfPolicyId, PolicyLevelsCompoundId, xrefPolicyLevelStartDate	, xrefPolicyLevelEndDate, XrefDataVarInd, DeprecatedDate)
SELECT 
	t.MasterPolicyNumber, t.PolicyNumber, t.SourceSystemId, t.SourceSystemDesc, t.PolicyType, t.TransactionDate, t.TransactionEffectiveDate, t.TransactionIssueDate, t.AccountingBookDate, t.TransactionType
	, MeasureName = 'Commission'
	, t.CurrencyCode
	, TransactionAmount_OC = c.TransactionAmount_OC 
	, TransactionAmount = c.TransactionAmount
	, TransactionAmount_OC = c.TransactionAmount_OC 
	, TransactionAmount = c.TransactionAmount
	, t.PolicyTransactionID, t.PolicyTransactionKey, t.DataVarInd, t.PolicyKey, t.PolicyID, t.AsOfPolicyId, t.PolicyLevelsCompoundId, t.xrefPolicyLevelStartDate
	, t.xrefPolicyLevelEndDate, t.XrefDataVarInd, t.DeprecatedDate 
FROM
	#Temp_BHSI_Transaction t, YodilIDS_Warehouse.Custom.PolicyTransaction c
WHERE
	t.PolicyTransactionKey = c.PolicyTransactionKey 
	AND	t.SourceSystemDesc = 'ODS'
	AND	c.MeasureName = 'Commission'
--	and t.PolicyNumber = '42-PRP-301149-01'
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
select * from #temp_Trans2 where policynumber = '40-PRI-302594-01' and sourcesystemdesc like '%policy' order by MeasureName, seq, TransactionDate
select * from #temp_Trans2 where policynumber = '42-EMC-302851-01' and sourcesystemdesc like '%policy' order by MeasureName, seq, TransactionDate
select * from #temp_Trans2 where policynumber = '42-PRP-000291-03' and sourcesystemdesc like '%policy' order by MeasureName, seq, TransactionDate
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
-- For Source Commission, Update TransactionAmount of ReviseBind entry with Reversal Entry
UPDATE
	t1
SET
--select t1.seq,
	TransactionAmount_OC = t1.TransactionAmount_OC + t2.TransactionAmount_OC 
	, TransactionAmount = t1.TransactionAmount + t2.TransactionAmount
--, t1.*
FROM
	#temp_Trans2 t1, #temp_Trans2 t2
WHERE
	t1.PolicyId = t2.PolicyId
	AND	t1.MeasureName = 'Commission'
	AND	t2.MeasureName = 'Commission'
	AND	t1.TransactionType IN ('ReviseBind')
	AND	t2.TransactionType IN ('Reversal')
	AND	t1.SourceSystemDesc LIKE 'BHSI%'
	AND	t1.Seq = t2.Seq + 1
--and t1.policynumber = '40-PRI-302594-01'
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
select top 100 * from #temp_Trans2 where policynumber = '42-RLO-301431-02' and MeasureName like 'w%'
select top 100 * from bhsi_processdate_update where masterpolicynumber = '42-RLO-301431-02' and actiontype like 'up%'
*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ProcessDate
-- Update 1 - Compare TransactionEffectiveDate
UPDATE
	pd
SET
	ProcessDate =	CASE	WHEN CONVERT (VARCHAR (10), pd.TransactionEffectiveDate, 120) > CONVERT (VARCHAR (10), pd.TransactionDate, 120) 
												THEN CONVERT (VARCHAR (10), pd.TransactionEffectiveDate, 120)
											ELSE	CONVERT (VARCHAR (10), pd.TransactionDate, 120)
								END
FROM
	#temp_Trans2 pd
		LEFT JOIN EDW..BHSI_ProcessDateCalendar cal
			ON	pd.Region = cal.Region
			AND	CONVERT (VARCHAR (10), pd.TransactionEffectiveDate, 120) >= CONVERT (VARCHAR (10), cal.StartDate, 120)
			AND	CONVERT (VARCHAR (10), pd.TransactionEffectiveDate, 120) < CONVERT (VARCHAR (10), cal.EndDate, 120)
WHERE
	CONVERT (VARCHAR (10), pd.TransactionDate, 120) <= CONVERT (VARCHAR (10), cal.CutOffDate, 120)
	AND	pd.SourceSystemDesc LIKE 'BHSI%'
	--AND	pd.TransactionType IN ('New', 'Renew', 'Adj - Renew', 'Cancel', 'Adj - Cancel', 'CancelBind', 'Adj - CancelBind', 'Endorse', 'Adj - Endorse', 'Reinstate', 'Adj - Reinstate', 'ReviseBind', 'Adj - ReviseBind', 'Information'
	--		, 'Reversal', 'ReviseEffectiveDate', 'Rewrite')

-- Update 2 - Compare ActualProcessDate - when ActualProcessDate is greater than or equal to StartDate and Less than or equal to CutOffDate then ActualProcessDate
UPDATE
	pd
SET
	ProcessDate = CONVERT (VARCHAR (10), pd.TransactionDate, 120)
FROM
	#temp_Trans2 pd
		LEFT JOIN EDW..BHSI_ProcessDateCalendar cal
			ON	pd.Region = cal.Region
WHERE
	pd.ProcessDate	 IS NULL
	AND	CONVERT (VARCHAR (10), pd.TransactionDate, 120) >= CONVERT (VARCHAR (10), cal.StartDate, 120)
	AND	CONVERT (VARCHAR (10), pd.TransactionDate, 120) <= CONVERT (VARCHAR (10), cal.CutOffDate, 120)
	AND	pd.SourceSystemDesc LIKE 'BHSI%'
	--AND	pd.TransactionType IN ('New', 'Renew', 'Adj - Renew', 'Cancel', 'Adj - Cancel', 'CancelBind', 'Adj - CancelBind', 'Endorse', 'Adj - Endorse', 'Reinstate', 'Adj - Reinstate', 'ReviseBind', 'Adj - ReviseBind', 'Information'
	--		, 'Reversal', 'ReviseEffectiveDate', 'Rewrite')

-- Update 3 - Compare ActualProcessDate - When ActualProcessDate is greater than CutOffDate and Less Than EndDate then EndDate
UPDATE
	pd
SET
	ProcessDate = CONVERT (VARCHAR (10), cal.EndDate, 120)
FROM
	#temp_Trans2 pd
		LEFT JOIN EDW..BHSI_ProcessDateCalendar cal
			ON	pd.Region = cal.Region
WHERE
	pd.ProcessDate	 IS NULL
	AND	CONVERT (VARCHAR (10), pd.TransactionDate, 120) > CONVERT (VARCHAR (10), cal.CutOffDate, 120)
	AND	CONVERT (VARCHAR (10), pd.TransactionDate, 120) < CONVERT (VARCHAR (10), cal.EndDate, 120)
	AND	pd.SourceSystemDesc LIKE 'BHSI%'
	--AND	pd.TransactionType IN ('New', 'Renew', 'Adj - Renew', 'Cancel', 'Adj - Cancel', 'CancelBind', 'Adj - CancelBind', 'Endorse', 'Adj - Endorse', 'Reinstate', 'Adj - Reinstate', 'ReviseBind', 'Adj - ReviseBind', 'Information'
	--		, 'Reversal', 'ReviseEffectiveDate', 'Rewrite')
---------------------------------------------------------------------------------------------------------------------------------------------------
-- select * from #Temp_BHSI_Transaction where sourcesystemdesc like 'bhsi%' and processdate is null
---------------------------------------------------------------------------------------------------------------------------------------------------
-- Assign AccountingBookDate to ProcessDate for ODS Data
UPDATE
	pd
SET
	ProcessDate = CONVERT (DATE, pd.AccountingBookDate)
FROM
	#temp_Trans2 pd
WHERE
	pd.ProcessDate	 IS NULL
-----------------------------------------------------------------------------------------------------------------------------------------------------
/*
select top 100 ProcessDate, DataVarInd, TransactionAmount_OC, Src_TransactionAmount_OC, RootDctId, HistoryId, TransactionType, * from #temp_Trans2 where policynumber = '42-PRP-301375-02' and policytype = 'p' and MeasureName like 'w%' order by 1, 2
*/
-----------------------------------------------------------------------------------------------------------------------------------------------------
-- ProcessDate Manual Update from BHSI_ProcessDate_Update table
UPDATE
	t
SET
-- select t.*, 
	ProcessDate = p.ProcessDate
FROM
	#temp_Trans2 t, EDW.dbo.BHSI_ProcessDate_Update p
WHERE
	t.RootDctId = p.RootDctId
	AND	t.HistoryId = p.HistoryId
	AND	p.ActionType = 'Update Process Date'
	--AND	t.CurrentStatus = p.CurrentStatus
	AND	t.CurrentStatus = case when p.CurrentStatus='Reversal' then 'Re-Entry' else p.CurrentStatus end
--and t.PolicyNumber = '42-STL-303326-01'

-- ProcessDate Update from EDW
UPDATE
	t
SET
-- select t.ProcessDate, p.ProcessDate, t.PolicyNumber, t.TransactionAmount_Oc, t.CurrentStatus, p.CurrentStatus, *,
	ProcessDate = p.ProcessDate
FROM
	#temp_Trans2 t, EDW.dbo.BHSI_ProcessDate_Update p
WHERE
	t.RootDctId = p.RootDctId
	AND	t.HistoryId = p.HistoryId
	AND	t.CurrentStatus = p.CurrentStatus 
	AND	p.ActionType = 'Update Process Date From EDW'
	AND	t.TransactionType = p.TransactionType
	AND	t.TransactIonType NOT LIKE 'Adj%'
-- and t.PolicyNumber = '42-STL-303326-01'

UPDATE
	t
SET
-- select t.ProcessDate, p.ProcessDate, t.PolicyNumber, t.TransactionAmount_Oc, t.CurrentStatus, p.CurrentStatus, *,
	ProcessDate = p.ProcessDate
FROM
	#temp_Trans2 t, EDW.dbo.BHSI_ProcessDate_Update p
WHERE
	t.RootDctId = p.RootDctId
	AND	t.HistoryId = p.HistoryId
	AND	t.CurrentStatus = p.CurrentStatus 
	AND	t.TransactionType = p.TransactionType
	AND	p.ActionType = 'Update Process Date From EDW'
	AND	t.TransactIonType LIKE 'Adj%'
-----------------------------------------------------------------------------------------------------------------------------------------------------
-- select top 100 ProcessDate, TransactionAmount_OC, RootDctId, HistoryId, TransactionType, * from #temp_Trans2 where policynumber = '42-PRP-000261-03' and policytype = 'p' and MeasureName like 'w%' order by 1

-- TODO !!!!!! update the PolicyID with correct value 
/*
select ProcessDate, TransactionAmount, * from #temp_Trans2
where policynumber like '%000211-03%'
and processdate='2016-04-01 00:00:00.000'	
and MeasureName='WrittenPremium'
order by TransactionDate, 1
*/
--- manual temporary update------
update #temp_Trans2
set transactionamount_oc=transactionamount_oc*-2,
	transactionamount   =transactionamount*-2
where policytransactionID=-1
and TransactionAmount>0


update #temp_Trans2  
set transactionamount_oc=0,transactionamount=0 
where policynumber='42-UMO-100191-02'-- and measurename='writtenpremium'
and processdate='2016-06-01 00:00:00.000'	
and transactiontype in ('Reversal', 'ReviseBind')
-----------------------------------------------------------------------------------------------------------------------------------------------------
update #temp_Trans2  
set transactionamount_oc=0,transactionamount=0 
where policynumber='42-PRP-301477-02'-- and measurename='writtenpremium'
and policytransactionkey='9534||72092||2016-07-29 13:11:46.7670000'
and transactiontype='Reversal'
-----------------------------------------------------------------------------------------------------------------------------------------------------
update #temp_Trans2  
set transactionamount_oc=0,transactionamount=0 
where policynumber='42-PRP-000257-04'-- and measurename='writtenpremium'
and policytransactionkey='23609||111647||2017-04-26 15:47:04.4000000'
and transactiontype='Reversal'
-----------------------------------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Final Table Insert
IF	OBJECT_ID ('EDW.dbo.BHSI_Transaction') IS NOT NULL	DROP TABLE EDW..BHSI_Transaction
-----------------------------------------------------------------------------------------------------------------------------------------------------
CREATE	TABLE EDW.dbo.BHSI_Transaction (
	PolicyId								INT
	, AsOfPolicyId						INT
	, PolicyNumber							VARCHAR (100)
	, MasterPolicyNumber					VARCHAR (100)
	, SourceSystemId						INT
	, SourceSystemDesc						VARCHAR (100)
	, PolicyType							VARCHAR (2)
	, TransactionDate						DATETIME2 NULL
	, TransactionEffectiveDate				DATETIME NULL
	, TransactionIssueDate					DATETIME NULL
	, AccountingBookDate					DATETIME NULL
	, TransactionType						VARCHAR (100) NULL
	, MeasureName							VARCHAR (100) NULL
	, CurrencyCode							VARCHAR (10) NULL
	, TransactionAmount_OC					NUMERIC (38, 8) NULL
	, TransactionAmount						NUMERIC (38, 8) NULL
	, PolicyTransactionId					INT NULL
	, PolicyTransactionKey					VARCHAR (150) NULL
	, DataVarInd							VARCHAR (2) NULL
	, PolicyKey								VARCHAR (100) NULL
	, PolicyLevelsCompoundID				INT NULL
	, XrefPolicyLevelStartDate				DATETIME2 NULL
	, XrefPolicyLevelEndDate				DATETIME2 NULL
	, XrefDataVarInd						VARCHAR (2) NULL
	, DeprecatedDate						DATETIME2
	, Src_TransactionAmount_OC				NUMERIC (38, 8) NULL
	, Src_TransactionAmount					NUMERIC (38, 8) NULL
	, RunningTransactionAmount_OC			NUMERIC (38, 8) NULL
	, RunningTransactionAmount				NUMERIC (38, 8) NULL
	, Seq									SMALLINT NULL
	, Region								VARCHAR (100) NULL
	, ProcessDate							DATETIME NULL
	, OldTransactionDate					DATETIME2 NULL
	, TransactionDateDerived				DATETIME2 NULL
)
-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Insert
INSERT	INTO	EDW.dbo.BHSI_Transaction
	(
	[PolicyId]
	, [AsOfPolicyId] 
	,[PolicyNumber]
	,[MasterPolicyNumber]
	,[SourceSystemId]
	,[SourceSystemDesc]
	,[PolicyType]
	,[TransactionDate]
	,[TransactionEffectiveDate]
	,[TransactionIssueDate]
	,[AccountingBookDate]
	,[TransactionType]
	,[MeasureName]
	,[CurrencyCode]
	,[TransactionAmount_OC]
	,[TransactionAmount]
	,[PolicyTransactionId]
	,[PolicyTransactionKey]
	,[DataVarInd]
	,[PolicyKey]
	,[PolicyLevelsCompoundID]
	,[XrefPolicyLevelStartDate]
	,[XrefPolicyLevelEndDate]
	,[XrefDataVarInd]
	,[DeprecatedDate]
	,Src_TransactionAmount_OC 
	,Src_TransactionAmount 
	,[RunningTransactionAmount_OC]
	,[RunningTransactionAmount]
	,[Seq]
	,[Region]
	,[ProcessDate]
	,[OldTransactionDate]
	,TransactionDateDerived
	)
SELECT 
	[PolicyId]
	, [AsOfPolicyId] 
	,[PolicyNumber]
	,[MasterPolicyNumber]
	,[SourceSystemId]
	,[SourceSystemDesc]
	,[PolicyType]
	,[TransactionDate]
	,[TransactionEffectiveDate]
	,[TransactionIssueDate]
	,[AccountingBookDate]
	,[TransactionType]
	,[MeasureName]
	,[CurrencyCode]
	,[TransactionAmount_OC]
	,[TransactionAmount]
	,[PolicyTransactionId]
	,[PolicyTransactionKey]
	,[DataVarInd]
	,[PolicyKey]
	,[PolicyLevelsCompoundID]
	,[XrefPolicyLevelStartDate]
	,[XrefPolicyLevelEndDate]
	,[XrefDataVarInd]
	,[DeprecatedDate]
	,Src_TransactionAmount_OC 
	,Src_TransactionAmount 
	,[RunningTransactionAmount_OC]
	,[RunningTransactionAmount]
	,[Seq]
	,[Region]
	,[ProcessDate]
	,[OldTransactionDate]
	, TransactionDateDerived
  FROM 
	#temp_Trans2


dROP INDEX IF EXISTS dbo.BHSI_Transaction.bhsi_trans_index1
CREATE NONCLUSTERED INDEX bhsi_trans_index1
ON [dbo].[BHSI_Transaction] ([MeasureName])
INCLUDE ([PolicyId],[PolicyType],[TransactionDate],[TransactionEffectiveDate],[TransactionType],[TransactionAmount_OC],[TransactionAmount],[PolicyTransactionId],[PolicyTransactionKey],[RunningTransactionAmount_OC],[RunningTransactionAmount],[ProcessDate])


/**
select * from #temp_Trans2
where --TransactionAmount = 425750
PolicyNumber  in ('42-PRP-301276-02', '42-PRP-000059-04')
**/









