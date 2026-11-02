// Auto-Zero Humanity Cyberdecks
// Automatically sets all cyberdeck items to 0 humanity cost.

module AutoZeroHumanityCyberdecks

public class AutoZeroHumanityCyberdecksSystem extends ScriptableSystem {
    private let initialized: Bool = false;

    private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
        if this.initialized {
            return;
        }
        this.initialized = true;

        let batch: ref<TweakDBBatch> = TweakDBManager.StartBatch();

        for record in TweakDBInterface.GetRecords(n"Item_Record") {
            let itemRecord: ref<Item_Record> = record as Item_Record;
            if IsDefined(itemRecord) {
                let isCyberdeck: Bool = false;

                if itemRecord.TagsContains(n"Cyberdeck") {
                    isCyberdeck = true;
                }

                if !isCyberdeck {
                    let bp: wref<ItemBlueprint_Record> = itemRecord.Blueprint();
                    if IsDefined(bp) {
                        let bpId: TweakDBID = bp.GetID();
                        if Equals(bpId, t"Items.CyberdeckBlueprint2Slots") ||
                           Equals(bpId, t"Items.CyberdeckBlueprint3Slots") ||
                           Equals(bpId, t"Items.CyberdeckBlueprint4Slots") ||
                           Equals(bpId, t"Items.CyberdeckBlueprint5Slots") {
                            isCyberdeck = true;
                        }
                    }
                }

                if isCyberdeck {
                    let itemTDBID: TweakDBID = itemRecord.GetID();
                    let variantsFlat: TweakDBID = itemTDBID + t".variants";
                    
                    let variants: array<TweakDBID>;
                    ArrayPush(variants, t"Variants.Humanity0Cost");
                    batch.SetFlat(variantsFlat, variants);
                    batch.SetFlat(itemTDBID + t".usesVariants", true);
                    batch.UpdateRecord(itemTDBID);
                }
            }
        }

        batch.Commit();
    }
}