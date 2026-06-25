package dev.nebulatrace.cargo;

import java.util.List;
import java.util.Map;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
public class CargoApiApplication {
  public static void main(String[] args) {
    SpringApplication.run(CargoApiApplication.class, args);
  }
}

@RestController
class CargoController {
  private final JdbcTemplate jdbc;

  CargoController(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  @GetMapping("/healthz")
  Map<String, Object> health() {
    return Map.of("ok", true, "service", "cargo-api");
  }

  @GetMapping("/cargo")
  List<Map<String, Object>> cargo() {
    if ("slow-db".equals(System.getenv("ENTROPY_MODE"))) {
      jdbc.queryForObject("select 1 from pg_sleep(2)", Integer.class);
    }
    return jdbc.queryForList("select sku, name, stock from cargo order by sku limit 20");
  }
}
