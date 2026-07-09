package com.repairshop.saas.masterdata.repository;

import com.repairshop.saas.masterdata.entity.MasterModel;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface MasterModelRepository extends JpaRepository<MasterModel, UUID> {

    List<MasterModel> findByBrandIdOrderByName(UUID brandId);

    List<MasterModel> findBySeriesIdOrderByName(UUID seriesId);

    List<MasterModel> findByCategoryIdOrderByName(UUID categoryId);

    /** Exact (case-insensitive) manufacturer model-number match — the bridge
     *  used by the IMEI.info lookup (e.g. "CPH2735" -> OPPO A5 5G). */
    List<MasterModel> findByModelNumberIgnoreCase(String modelNumber);
}
